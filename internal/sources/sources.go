package sources

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
)

//go:embed sources.json
var rawCatalog []byte

// Source is one known Endel soundscape.
type Source struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Modality string `json:"modality"`
}

type catalogFile struct {
	Sources []Source          `json:"sources"`
	Aliases map[string]string `json:"aliases"`
}

var (
	All     []Source
	Aliases map[string]string
	byID    map[string]Source
)

func init() {
	var catalog catalogFile
	if err := json.Unmarshal(rawCatalog, &catalog); err != nil {
		panic(fmt.Sprintf("sources catalog: %v", err))
	}
	if len(catalog.Sources) == 0 {
		panic("sources catalog: empty sources list")
	}
	if catalog.Aliases == nil {
		catalog.Aliases = map[string]string{}
	}

	All = catalog.Sources
	Aliases = catalog.Aliases
	byID = make(map[string]Source, len(catalog.Sources))
	for _, source := range catalog.Sources {
		byID[source.ID] = source
	}
}

// IsKnown reports whether id is a catalog source id.
func IsKnown(id string) bool {
	_, ok := byID[id]
	return ok
}

// ResolveAlias returns the canonical id for a known alias, or the input.
func ResolveAlias(id string) string {
	if alias, ok := Aliases[id]; ok {
		return alias
	}
	return id
}

// Normalize turns a user-facing id, name, or soundscape URL into a known slug.
func Normalize(raw string) (string, error) {
	source := strings.TrimSpace(raw)
	if source == "" {
		return "", fmt.Errorf("source cannot be empty")
	}

	if parsed, err := url.Parse(source); err == nil && parsed.Scheme != "" {
		source = SoundscapeSlugFromPath(parsed.Path)
		if source == "" {
			return "", fmt.Errorf("URL does not include a soundscape slug: %s", raw)
		}
	}

	source = SourceID(source)
	for _, char := range source {
		if (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') || char == '-' {
			continue
		}
		return "", fmt.Errorf("invalid source slug %q: use lowercase letters, numbers, and hyphens", raw)
	}

	source = ResolveAlias(source)
	if !IsKnown(source) {
		return "", fmt.Errorf("unknown source %q; run: endelito sources", raw)
	}

	return source, nil
}

// SourceID lowercases and hyphenates a raw name.
func SourceID(raw string) string {
	source := strings.ToLower(strings.TrimSpace(raw))
	source = strings.ReplaceAll(source, "_", "-")
	source = strings.Join(strings.Fields(source), "-")
	return source
}

// SoundscapeSlugFromPath extracts the slug after /soundscape/ in a URL path.
func SoundscapeSlugFromPath(path string) string {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	for index, part := range parts {
		if part == "soundscape" && index+1 < len(parts) {
			return parts[index+1]
		}
	}
	return ""
}
