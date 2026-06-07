// Package loader reads sample log lines from files or directories into memory so
// the benchmark workers can replay them at high speed without touching disk in
// the hot path.
package loader

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Corpus is an in-memory set of log lines to replay.
type Corpus struct {
	Lines [][]byte
	Bytes int64 // total bytes across all lines (excluding newlines)
}

// Load reads every path in paths. A path may be a file or a directory; for a
// directory all regular files within it (non-recursive) are read. Blank lines
// are skipped. The order of lines is preserved per file.
func Load(paths []string) (*Corpus, error) {
	c := &Corpus{}
	for _, p := range paths {
		info, err := os.Stat(p)
		if err != nil {
			return nil, fmt.Errorf("stat %s: %w", p, err)
		}
		if info.IsDir() {
			entries, err := os.ReadDir(p)
			if err != nil {
				return nil, fmt.Errorf("read dir %s: %w", p, err)
			}
			for _, e := range entries {
				if e.IsDir() {
					continue
				}
				if err := c.loadFile(filepath.Join(p, e.Name())); err != nil {
					return nil, err
				}
			}
			continue
		}
		if err := c.loadFile(p); err != nil {
			return nil, err
		}
	}
	if len(c.Lines) == 0 {
		return nil, fmt.Errorf("no log lines loaded from %v", paths)
	}
	return c, nil
}

func (c *Corpus) loadFile(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open %s: %w", path, err)
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	// Some real log lines are long; allow up to 1 MiB per line.
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r\n")
		if line == "" {
			continue
		}
		b := []byte(line)
		c.Lines = append(c.Lines, b)
		c.Bytes += int64(len(b))
	}
	if err := sc.Err(); err != nil {
		return fmt.Errorf("scan %s: %w", path, err)
	}
	return nil
}

// AvgLineBytes returns the mean line length in bytes.
func (c *Corpus) AvgLineBytes() float64 {
	if len(c.Lines) == 0 {
		return 0
	}
	return float64(c.Bytes) / float64(len(c.Lines))
}
