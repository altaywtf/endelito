package sources

import (
	"strings"
	"testing"
)

func TestNormalize(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want string
	}{
		{name: "slug", raw: "focus", want: "focus"},
		{name: "trim and lowercase", raw: "  Relax  ", want: "relax"},
		{name: "route URL", raw: "https://play.endel.io/en/soundscape/dynamic-focus", want: "dynamic-focus"},
		{name: "route URL with query", raw: "https://play.endel.io/en/soundscape/solfeggio-tones?foo=bar", want: "solfeggio-tones"},
		{name: "space separated name", raw: "Nature Elements", want: "nature-elements"},
		{name: "alias rainy outside", raw: "rainy outside", want: "rainy"},
		{name: "alias 8d", raw: "8d", want: "8d-odyssey"},
		{name: "alias deeper", raw: "deeper", want: "plastikman"},
		{name: "alias alan-watts", raw: "alan-watts", want: "wisdom"},
		{name: "alias spatial-orbit", raw: "spatial-orbit", want: "spatial"},
		{name: "alias wind-down", raw: "wind-down", want: "winddown"},
		{name: "alias color-noise", raw: "color-noise", want: "colored-noise"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := Normalize(test.raw)
			if err != nil {
				t.Fatalf("Normalize(%q) returned error: %v", test.raw, err)
			}
			if got != test.want {
				t.Fatalf("Normalize(%q) = %q, want %q", test.raw, got, test.want)
			}
		})
	}
}

func TestNormalizeRejectsInvalidValues(t *testing.T) {
	tests := []string{
		"",
		"white noise",
		"../../focus",
		"deep-work",
		"https://play.endel.io/en/player",
	}

	for _, raw := range tests {
		t.Run(raw, func(t *testing.T) {
			if got, err := Normalize(raw); err == nil {
				t.Fatalf("Normalize(%q) = %q, want error", raw, got)
			}
		})
	}
}

func TestNormalizeUnknownMentionsSources(t *testing.T) {
	_, err := Normalize("deep-work")
	if err == nil {
		t.Fatal("expected error")
	}
	if !strings.Contains(err.Error(), "endelito sources") {
		t.Fatalf("error %q should mention endelito sources", err)
	}
}

func TestSoundscapeSlugFromPath(t *testing.T) {
	tests := map[string]string{
		"/en/soundscape/focus":    "focus",
		"/soundscape/relax/extra": "relax",
		"/en/player":              "",
		"soundscape":              "",
	}
	for path, want := range tests {
		if got := SoundscapeSlugFromPath(path); got != want {
			t.Fatalf("SoundscapeSlugFromPath(%q) = %q, want %q", path, got, want)
		}
	}
}

func TestCatalogParity(t *testing.T) {
	if len(All) < 17 {
		t.Fatalf("expected at least 17 sources, got %d", len(All))
	}
	for alias, target := range Aliases {
		if !IsKnown(target) {
			t.Fatalf("alias %q points at unknown source %q", alias, target)
		}
	}
}
