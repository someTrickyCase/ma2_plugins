package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

const (
	spaceMark   = " "
	pickMark    = "x"
	cursorMark  = ">"
	pluginLines = 6
	versionLine = 4
)

func (model Model) View() string {
	if model.step == stepVersions {
		return model.versionView()
	}

	return model.pluginView()
}

func (model Model) pluginView() string {
	lines := make([]string, 0, len(model.plugins)+pluginLines)

	lines = append(lines,
		titleText("MA2 plugin installer"),
		"",
		titleText("Plugins"),
		"",
	)

	for index, item := range model.plugins {
		lines = append(lines, model.pluginLine(index, item))
	}

	lines = append(lines,
		"",
		hintText("space: pick   enter: next   esc: quit"),
	)

	return strings.Join(lines, "\n")
}

func (model Model) pluginLine(index int, item Item) string {
	pointer := spaceMark
	mark := spaceMark

	if index == model.cursor {
		pointer = cursorMark
	}

	if model.chosen[index] {
		mark = pickMark
	}

	line := fmt.Sprintf("%s [%s] %s  %s  slot %d",
		pointer,
		mark,
		item.Name,
		item.Version,
		item.Slot,
	)

	if index == model.cursor {
		return markerText(line)
	}

	return line
}

func (model Model) versionView() string {
	lines := make([]string, 0, len(model.versions)+versionLine)

	lines = append(lines,
		titleText("MA2 version"),
		"",
	)

	for index, version := range model.versions {
		pointer := spaceMark
		if index == model.cursor {
			pointer = cursorMark
		}

		line := pointer + " " + version.Text

		if index == model.cursor {
			line = markerText(line)
		}

		lines = append(lines, line)
	}

	lines = append(lines,
		"",
		hintText("enter: install   esc: back   q: quit"),
	)

	return strings.Join(lines, "\n")
}

func titleText(text string) string {
	return lipgloss.NewStyle().Bold(true).Render(text)
}

func markerText(text string) string {
	return lipgloss.NewStyle().Bold(true).
		Foreground(lipgloss.Color("42")).
		Render(text)
}

func hintText(text string) string {
	return lipgloss.NewStyle().Faint(true).Render(text)
}
