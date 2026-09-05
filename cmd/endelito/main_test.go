package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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

// Exercise the shipped entrypoint with synthetic Launch Services commands only.
func TestCLITransportKeepsSelectedApp(t *testing.T) {
	root := t.TempDir()
	binary := filepath.Join(root, "endelito")
	build := exec.Command("go", "build", "-o", binary, ".")
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build CLI: %v: %s", err, output)
	}
	app := filepath.Join(root, "Chosen Copy.app")
	if err := os.Mkdir(app, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, fixture := range []struct{ name, body string }{
		{"open", "#!/bin/sh\nprintf '%s\\n' --call-- \"$@\" >> \"$ENDELITO_TEST_LOG\"\n: > \"$ENDELITO_TEST_LOG.started\"\nexit \"${ENDELITO_TEST_OPEN_EXIT:-0}\"\n"},
		{"pgrep", "#!/bin/sh\n[ \"$ENDELITO_TEST_RUNNING\" = 0 ] || [ -f \"$ENDELITO_TEST_LOG.started\" ]\n"},
	} {
		if err := os.WriteFile(filepath.Join(root, fixture.name), []byte(fixture.body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	for _, running := range []string{"0", "1"} {
		t.Run("other-copy-running-"+running, func(t *testing.T) {
			log := filepath.Join(t.TempDir(), "calls")
			command := exec.Command(binary, "play", "relax")
			command.Env = append(os.Environ(), "PATH="+root+":"+os.Getenv("PATH"), "ENDELITO_APP="+app, "ENDELITO_TEST_LOG="+log, "ENDELITO_TEST_RUNNING="+running)
			if output, err := command.CombinedOutput(); err != nil {
				t.Fatalf("CLI: %v: %s", err, output)
			}
			calls, err := os.ReadFile(log)
			if err != nil {
				t.Fatal(err)
			}
			if want := "--call--\n-a\n" + app + "\nendelito://play?source=relax\n"; string(calls) != want {
				t.Fatalf("open args = %q, want %q", calls, want)
			}
		})
	}
	t.Run("missing-override-does-not-fall-back", func(t *testing.T) {
		log := filepath.Join(t.TempDir(), "calls")
		command := exec.Command(binary, "pause")
		command.Env = append(os.Environ(), "PATH="+root+":"+os.Getenv("PATH"), "ENDELITO_APP="+filepath.Join(root, "Missing.app"), "ENDELITO_TEST_LOG="+log, "ENDELITO_TEST_RUNNING=0")
		output, err := command.CombinedOutput()
		if err == nil || !strings.Contains(string(output), "ENDELITO_APP does not exist") {
			t.Fatalf("CLI: %v: %s", err, output)
		}
		if _, err := os.Stat(log); !os.IsNotExist(err) {
			t.Fatalf("unexpected open call: %v", err)
		}
	})
	t.Run("delivery-failure", func(t *testing.T) {
		command := exec.Command(binary, "pause")
		command.Env = append(os.Environ(), "PATH="+root+":"+os.Getenv("PATH"), "ENDELITO_APP="+app, "ENDELITO_TEST_LOG="+filepath.Join(t.TempDir(), "calls"), "ENDELITO_TEST_OPEN_EXIT=1")
		if output, err := command.CombinedOutput(); err == nil {
			t.Fatalf("CLI unexpectedly succeeded: %s", output)
		}
	})
}
