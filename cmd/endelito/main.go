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

	"endelito/internal/sources"
)

const (
	appBundleID = "local.endelito"
	appScheme   = "endelito"
	appName     = "Endelito"
)

var version = "dev"

type liteState struct {
	App              string `json:"app"`
	URL              string `json:"url"`
	Source           string `json:"source"`
	SourceName       string `json:"sourceName"`
	IsPlaying        bool   `json:"isPlaying"`
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
	case "version", "--version", "-v":
		fmt.Println(version)
		return nil
	case "status":
		return printStatus()
	case "sources", "list-sources", "soundscapes":
		printSources()
		return nil
	case "play":
		if len(args) > 1 {
			source, err := sources.Normalize(args[1])
			if err != nil {
				return err
			}
			return sendCommand("play?source=" + url.QueryEscape(source))
		}

		return sendCommand(command)
	case "source", "soundscape":
		if len(args) < 2 {
			return errors.New("expected: endelito source <id-or-name>")
		}
		source, err := sources.Normalize(args[1])
		if err != nil {
			return err
		}
		return sendCommand("source?slug=" + url.QueryEscape(source))
	case "launch", "show", "hide", "reload", "quit", "pause", "toggle", "debug":
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
		"  version",
		"  launch | show | hide | reload | quit",
		"  play [source] | pause | toggle",
		"  source <id-or-name>",
		"  sources",
		"  deeplink <url>",
	}, "\n")
}

func printSources() {
	modality := ""
	for _, source := range sources.All {
		if source.Modality != modality {
			modality = source.Modality
			fmt.Printf("%s:\n", modality)
		}

		fmt.Printf("  %-16s %s\n", source.ID, source.Name)
	}
}

func sendCommand(command string) error {
	commandURL := appScheme + "://" + command
	for _, appPath := range candidateAppPaths() {
		if pathExists(appPath) {
			return open("-a", appPath, commandURL)
		}
	}
	if appPath := os.Getenv("ENDELITO_APP"); appPath != "" {
		return fmt.Errorf("ENDELITO_APP does not exist: %s", appPath)
	}
	if err := open("-b", appBundleID, commandURL); err != nil {
		return fmt.Errorf("%s could not accept the command; run: make install (%w)", appName, err)
	}
	return nil
}

func candidateAppPaths() []string {
	if appPath := os.Getenv("ENDELITO_APP"); appPath != "" {
		return []string{appPath}
	}

	paths := make([]string, 0, 3)
	if localPath, err := localAppPath(); err == nil {
		paths = append(paths, localPath)
	}
	paths = append(paths, filepath.Join("/Applications", appName+".app"))
	if home, err := os.UserHomeDir(); err == nil {
		paths = append(paths, filepath.Join(home, "Applications", appName+".app"))
	}
	return paths
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

	fmt.Printf("%s: %s\n", state.App, playback)
	if state.Source != "" {
		if state.SourceName != "" {
			fmt.Printf("source: %s (%s)\n", state.Source, state.SourceName)
		} else {
			fmt.Printf("source: %s\n", state.Source)
		}
	} else if state.URL != "" {
		fmt.Printf("url: %s\n", state.URL)
	}
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
