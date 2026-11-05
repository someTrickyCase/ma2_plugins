package setup

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"slices"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

func Interactive(
	args []string,
	stdout, stderr io.Writer,
	pick Picker,
	show func(string) error,
) int {
	if slices.Contains(args, "--all") || slices.Contains(args, "--all=true") {
		return Run(args, stdout, stderr, pick)
	}

	var output, problems bytes.Buffer

	cancelled := false

	livePick := func(
		_ io.Writer,
		items []tui.Item,
		versions []mahome.Version,
	) (tui.Selection, error) {
		selection, err := pick(stdout, items, versions)
		cancelled = errors.Is(err, tui.ErrCancelled)

		return selection, err
	}
	code := Run(args, &output, &problems, livePick)

	if cancelled {
		return 0
	}

	_, _ = io.Copy(stdout, bytes.NewReader(output.Bytes()))
	_, _ = io.Copy(stderr, bytes.NewReader(problems.Bytes()))

	err := show(output.String() + problems.String())
	if err != nil {
		_, _ = fmt.Fprintln(stderr, err)

		return 1
	}

	return code
}
