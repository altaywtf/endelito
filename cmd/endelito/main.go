package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	appBundleID = "local.endelito"
	appScheme   = "endelito"
	appName     = "Endelito"
)

type liteState struct {
	App              string `json:"app"`
	URL              string `json:"url"`
	IsPlaying        bool   `json:"isPlaying"`
	Muted            bool   `json:"muted"`
	DynamicMenuCount int    `json:"dynamicMenuCount"`
	UpdatedAt        string `json:"updatedAt"`
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string) error {
	command := "help"
	if len(args) > 0 {
		command = args[0]
	}

	switch command {
	case "help", "--help", "-h":
		fmt.Println(usage())
		return nil
	case "status":
		return printStatus()
	case "launch", "show", "hide", "reload", "quit", "play", "pause", "toggle", "mute", "unmute", "toggle-mute", "debug":
		return sendCommand(command)
	case "deeplink":
		if len(args) < 2 {
			return errors.New("expected: endelito deeplink <url>")
		}
		return sendCommand("deeplink?url=" + url.QueryEscape(args[1]))
	default:
		return fmt.Errorf("unknown command: %s\n\n%s", command, usage())
	}
}

func usage() string {
	return strings.Join([]string{
		"Usage: endelito <command>",
		"",
		"Commands:",
		"  status",
		"  launch | show | hide | reload | quit",
		"  play | pause | toggle",
		"  mute | unmute | toggle-mute",
		"  deeplink <url>",
	}, "\n")
}

func sendCommand(command string) error {
	if err := launchApp(); err != nil {
		return err
	}

	time.Sleep(150 * time.Millisecond)
	return open(appScheme + "://" + command)
}

func launchApp() error {
	if isAppRunning() {
		return nil
	}

	appPath := os.Getenv("ENDELITO_APP")
	if appPath != "" {
		return startAppBundle(appPath)
	}

	appPath, err := localAppPath()
	if err == nil && pathExists(appPath) {
		return startAppBundle(appPath)
	}

	if err := open("-b", appBundleID); err == nil {
		return nil
	}

	if err != nil {
		return err
	}

	return startAppBundle(appPath)
}

func localAppPath() (string, error) {
	executable, err := os.Executable()
	if err != nil {
		return "", err
	}

	return filepath.Join(filepath.Dir(filepath.Dir(executable)), "build", appName+".app"), nil
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func startAppBundle(appPath string) error {
	return exec.Command(filepath.Join(appPath, "Contents", "MacOS", appName)).Start()
}

func isAppRunning() bool {
	return exec.Command("pgrep", "-x", appName).Run() == nil
}

func printStatus() error {
	state, err := readState()
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			fmt.Println("Endelito has not written state yet. Run: endelito launch")
			return nil
		}

		return err
	}

	playback := "paused"
	if state.IsPlaying {
		playback = "playing"
	}

	audio := "unmuted"
	if state.Muted {
		audio = "muted"
	}

	fmt.Printf("%s: %s\n", state.App, playback)
	fmt.Printf("audio: %s\n", audio)
	fmt.Printf("menu items: %d\n", state.DynamicMenuCount)
	fmt.Printf("updated: %s\n", state.UpdatedAt)
	return nil
}

func readState() (liteState, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return liteState{}, err
	}

	path := filepath.Join(home, "Library", "Application Support", appName, "state.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return liteState{}, err
	}

	var state liteState
	if err := json.Unmarshal(data, &state); err != nil {
		return liteState{}, err
	}

	return state, nil
}

func open(args ...string) error {
	command := exec.Command("open", args...)
	output, err := command.CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message == "" {
			return err
		}

		return fmt.Errorf("%s: %w", message, err)
	}

	return nil
}
