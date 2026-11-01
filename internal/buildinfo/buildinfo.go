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

func Commit() string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return unknown
	}

	return CommitOf(info.Settings)
}

func Describe(settings []debug.BuildSetting) string {
	commit := CommitOf(settings)
	if commit == unknown {
		return unknown
	}

	values := valuesOf(settings)

	return commit + " (" + prefix(values[keyCommitTime], dateSize) + ")"
}

func CommitOf(settings []debug.BuildSetting) string {
	values := valuesOf(settings)

	commit := values[keyRevision]
	if commit == "" {
		return unknown
	}

	commit = prefix(commit, shortHashSize)
	if values[keyModified] == modifiedMarker {
		commit += dirtySuffix
	}

	return commit
}

func valuesOf(settings []debug.BuildSetting) map[string]string {
	values := make(map[string]string, len(settings))
	for _, setting := range settings {
		values[setting.Key] = setting.Value
	}

	return values
}

func prefix(text string, size int) string {
	return text[:min(len(text), size)]
}
