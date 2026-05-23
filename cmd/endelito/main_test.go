package main

import "testing"

func TestNormalizeSource(t *testing.T) {
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
		{name: "alias", raw: "rainy outside", want: "rainy"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := normalizeSource(test.raw)
			if err != nil {
				t.Fatalf("normalizeSource(%q) returned error: %v", test.raw, err)
			}
			if got != test.want {
				t.Fatalf("normalizeSource(%q) = %q, want %q", test.raw, got, test.want)
			}
		})
	}
}

func TestNormalizeSourceRejectsInvalidValues(t *testing.T) {
	tests := []string{
		"",
		"white noise",
		"../../focus",
		"deep-work",
		"https://play.endel.io/en/player",
	}

	for _, raw := range tests {
		t.Run(raw, func(t *testing.T) {
			if got, err := normalizeSource(raw); err == nil {
				t.Fatalf("normalizeSource(%q) = %q, want error", raw, got)
			}
		})
	}
}
