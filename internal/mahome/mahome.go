package mahome

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
)

const (
	DefaultRoot  = `C:\ProgramData\MA Lighting Technologies\grandma`
	folderPrefix = "gma2_V_"
	pluginsName  = "plugins"
)

var (
	errNoVersion    = errors.New("no MA2 version folder found")
	errMissing      = errors.New("no MA2 version folder for this version")
	errBadVersion   = errors.New("cannot read the version")
	errReadVersions = errors.New("cannot read the MA2 folders")
)

type Version struct {
	Text  string
	Parts []int
}

func Newest(root string) (Version, error) {
	versions, err := Versions(root)
	if err != nil {
		return Version{}, err
	}

	if len(versions) == 0 {
		return Version{}, fmt.Errorf("%w in %q", errNoVersion, root)
	}

	return versions[len(versions)-1], nil
}

func (version Version) Folder() string {
	return folderPrefix + version.Text
}

func ParseVersion(text string) (Version, error) {
	if text == "" {
		return Version{}, fmt.Errorf("%w: it is empty", errBadVersion)
	}

	parts := []int{}

	for part := range strings.SplitSeq(text, ".") {
		number, err := strconv.Atoi(part)
		if err != nil {
			return Version{}, fmt.Errorf("%w %q: %w", errBadVersion, text, err)
		}

		parts = append(parts, number)
	}

	return Version{Text: text, Parts: parts}, nil
}

func Versions(root string) ([]Version, error) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, fmt.Errorf("%w %q: %w", errReadVersions, root, err)
	}

	found := []Version{}

	for _, entry := range entries {
		version, ok := versionOf(entry)
		if !ok {
			continue
		}

		found = append(found, version)
	}

	slices.SortFunc(found, compareVersions)

	return found, nil
}

func versionOf(entry os.DirEntry) (Version, bool) {
	if !entry.IsDir() {
		return Version{Text: "", Parts: []int{}}, false
	}

	name := entry.Name()
	if !strings.HasPrefix(name, folderPrefix) {
		return Version{Text: "", Parts: []int{}}, false
	}

	version, err := ParseVersion(strings.TrimPrefix(name, folderPrefix))
	if err != nil {
		return Version{Text: "", Parts: []int{}}, false
	}

	return version, true
}

func compareVersions(first Version, second Version) int {
	return slices.Compare(first.Parts, second.Parts)
}

func Pick(root string, wanted string) (Version, error) {
	if wanted == "" {
		return Newest(root)
	}

	versions, err := Versions(root)
	if err != nil {
		return Version{}, err
	}

	for _, version := range versions {
		if version.Text == wanted {
			return version, nil
		}
	}

	return Version{}, fmt.Errorf("%w %q in %q", errMissing, wanted, root)
}

func PluginsFolder(root string, version Version) string {
	return filepath.Join(root, version.Folder(), pluginsName)
}
