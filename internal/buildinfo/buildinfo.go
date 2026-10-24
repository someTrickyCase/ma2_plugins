package buildinfo

import "runtime/debug"

const (
	unknown        = "dev"
	shortHashSize  = 7
	dateSize       = len("2006-01-02")
	dirtySuffix    = "-dirty"
	keyRevision    = "vcs.revision"
	keyCommitTime  = "vcs.time"
	keyModified    = "vcs.modified"
	modifiedMarker = "true"
)

func Current() string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return unknown
	}

	return Describe(info.Settings)
}

func Describe(settings []debug.BuildSetting) string {
	values := make(map[string]string, len(settings))
	for _, setting := range settings {
		values[setting.Key] = setting.Value
	}

	commit := values[keyRevision]
	if commit == "" {
		return unknown
	}

	commit = prefix(commit, shortHashSize)
	if values[keyModified] == modifiedMarker {
		commit += dirtySuffix
	}

	return commit + " (" + prefix(values[keyCommitTime], dateSize) + ")"
}

func prefix(text string, size int) string {
	return text[:min(len(text), size)]
}
