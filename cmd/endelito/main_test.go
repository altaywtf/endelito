package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCandidateAppPathsIncludesApplications(t *testing.T) {
	t.Setenv("ENDELITO_APP", "")
	paths := candidateAppPaths()
	found := false
	for _, path := range paths {
		if path == filepath.Join("/Applications", appName+".app") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("candidateAppPaths() = %v, want /Applications/%s.app", paths, appName)
	}
}

func TestCandidateAppPathsHonorsOverride(t *testing.T) {
	override := filepath.Join(t.TempDir(), "Custom.app")
	t.Setenv("ENDELITO_APP", override)
	paths := candidateAppPaths()
	if len(paths) != 1 || paths[0] != override {
		t.Fatalf("candidateAppPaths() = %v, want [%s]", paths, override)
	}
}

func TestReadState(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	dir := filepath.Join(home, "Library", "Application Support", appName)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	payload := []byte(`{"app":"Endelito","url":"https://play.endel.io/en/soundscape/focus","source":"focus","sourceName":"Focus","isPlaying":true,"dynamicMenuCount":2,"updatedAt":"2026-01-01T00:00:00Z"}`)
	if err := os.WriteFile(filepath.Join(dir, "state.json"), payload, 0o644); err != nil {
		t.Fatal(err)
	}

	state, err := readState()
	if err != nil {
		t.Fatal(err)
	}
	if state.Source != "focus" || !state.IsPlaying || state.DynamicMenuCount != 2 {
		t.Fatalf("unexpected state: %+v", state)
	}
}
