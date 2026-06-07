package loader

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadFileAndDir(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "a.log"), "line1\nline2\n\nline3\n")
	writeFile(t, filepath.Join(dir, "b.log"), "x\r\ny\n")

	// Single file.
	c, err := Load([]string{filepath.Join(dir, "a.log")})
	if err != nil {
		t.Fatal(err)
	}
	if len(c.Lines) != 3 {
		t.Fatalf("want 3 lines (blank skipped), got %d", len(c.Lines))
	}

	// Directory loads both files.
	c, err = Load([]string{dir})
	if err != nil {
		t.Fatal(err)
	}
	if len(c.Lines) != 5 {
		t.Fatalf("want 5 lines from dir, got %d", len(c.Lines))
	}
	if c.AvgLineBytes() <= 0 {
		t.Fatalf("avg line bytes should be positive")
	}
}

func TestLoadEmptyErrors(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "empty.log"), "\n\n")
	if _, err := Load([]string{dir}); err == nil {
		t.Fatal("expected error on empty corpus")
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
