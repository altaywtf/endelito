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

type source struct {
	ID       string
	Name     string
	Modality string
}

var sources = []source{
	{ID: "focus", Name: "Focus", Modality: "focus"},
	{ID: "colored-noise", Name: "Colored Noise", Modality: "focus"},
	{ID: "dynamic-focus", Name: "Dynamic Focus", Modality: "focus"},
	{ID: "study", Name: "Study", Modality: "focus"},
	{ID: "plastikman", Name: "Deeper Focus", Modality: "focus"},
	{ID: "solfeggio-tones", Name: "Solfeggio Tones", Modality: "focus"},
	{ID: "relax", Name: "Relax", Modality: "relax"},
	{ID: "8d-odyssey", Name: "8D Odyssey", Modality: "relax"},
	{ID: "nature-elements", Name: "Nature Elements", Modality: "relax"},
	{ID: "spatial", Name: "Spatial Orbit", Modality: "relax"},
	{ID: "recovery", Name: "Recovery", Modality: "relax"},
	{ID: "wisdom", Name: "Wisdom", Modality: "relax"},
	{ID: "sleep", Name: "Sleep", Modality: "sleep"},
	{ID: "rainy", Name: "Rainy Outside", Modality: "sleep"},
	{ID: "winddown", Name: "Wind Down", Modality: "sleep"},
	{ID: "hibernation", Name: "Hibernation", Modality: "sleep"},
	{ID: "grimes", Name: "Grimes", Modality: "sleep"},
}

var sourceAliases = map[string]string{
	"8d":                       "8d-odyssey",
	"alan-watts":               "wisdom",
	"color-noise":              "colored-noise",
	"deeper":                   "plastikman",
	"rainy-outside":            "rainy",
	"spatial-orbit":            "spatial",
	"wind-down":                "winddown",
	"wind-down-by-james-blake": "winddown",
}

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
	case "status":
		return printStatus()
	case "sources", "list-sources", "soundscapes":
		printSources()
		return nil
	case "play":
		if len(args) > 1 {
			source, err := normalizeSource(args[1])
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
		source, err := normalizeSource(args[1])
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
		"  launch | show | hide | reload | quit",
		"  play [source] | pause | toggle",
		"  source <id-or-name>",
		"  sources",
		"  deeplink <url>",
	}, "\n")
}

func normalizeSource(raw string) (string, error) {
	source := strings.TrimSpace(raw)
	if source == "" {
		return "", errors.New("source cannot be empty")
	}

	if parsed, err := url.Parse(source); err == nil && parsed.Scheme != "" {
		source = soundscapeSlugFromPath(parsed.Path)
		if source == "" {
			return "", fmt.Errorf("URL does not include a soundscape slug: %s", raw)
		}
	}

	source = sourceID(source)
	for _, char := range source {
		if (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') || char == '-' {
			continue
		}

		return "", fmt.Errorf("invalid source slug %q: use lowercase letters, numbers, and hyphens", raw)
	}

	if alias, ok := sourceAliases[source]; ok {
		source = alias
	}
	if !isKnownSource(source) {
		return "", fmt.Errorf("unknown source %q; run: endelito sources", raw)
	}

	return source, nil
}

func sourceID(raw string) string {
	source := strings.ToLower(strings.TrimSpace(raw))
	source = strings.ReplaceAll(source, "_", "-")
	source = strings.Join(strings.Fields(source), "-")
	return source
}

func isKnownSource(id string) bool {
	for _, source := range sources {
		if source.ID == id {
			return true
		}
	}

	return false
}

func soundscapeSlugFromPath(path string) string {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	for index, part := range parts {
		if part == "soundscape" && index+1 < len(parts) {
			return parts[index+1]
		}
	}

	return ""
}

func printSources() {
	modality := ""
	for _, source := range sources {
		if source.Modality != modality {
			modality = source.Modality
			fmt.Printf("%s:\n", modality)
		}

		fmt.Printf("  %-16s %s\n", source.ID, source.Name)
	}
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
		return openAppBundle(appPath)
	}

	appPath, err := localAppPath()
	if err == nil && pathExists(appPath) {
		return openAppBundle(appPath)
	}

	if err := open("-b", appBundleID); err == nil {
		return waitForAppRunning()
	}

	return err
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

func openAppBundle(appPath string) error {
	if err := open(appPath); err != nil {
		return err
	}

	return waitForAppRunning()
}

func isAppRunning() bool {
	return exec.Command("pgrep", "-x", appName).Run() == nil
}

func waitForAppRunning() error {
	for range 20 {
		if isAppRunning() {
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}

	return fmt.Errorf("%s did not start", appName)
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
