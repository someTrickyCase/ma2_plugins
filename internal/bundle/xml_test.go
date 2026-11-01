package bundle_test

import (
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
)

const lineBreak = "\n"

func wantXML() string {
	return `<?xml version="1.0" encoding="utf-8"?>` + lineBreak +
		`<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ` +
		`xmlns="http://schemas.malighting.de/grandma2/xml/MA" ` +
		`xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA ` +
		`http://schemas.malighting.de/grandma2/xml/3.0.187/MA.xsd" ` +
		`major_vers="3" minor_vers="0" stream_vers="187">` + lineBreak +
		`    <Info datetime="2026-10-24T00:00:00" ` +
		`showfile="k-answer" />` + lineBreak +
		`    <Plugin index="1" execute_on_load="0" name="Answer" ` +
		`luafile="k-answer.lua" />` + lineBreak +
		"</MA>\n"
}

func TestXML(t *testing.T) {
	t.Parallel()

	got := bundle.XML(answerPlugin([]bundle.Module{}))

	if got != wantXML() {
		t.Errorf("XML() =\n%s\nwant\n%s", got, wantXML())
	}
}

func TestXMLEscapesTheSpecialCharacters(t *testing.T) {
	t.Parallel()

	plugin := answerPlugin([]bundle.Module{})
	plugin.Manifest.Name = `Fix & "Cha" <1>`

	got := bundle.XML(plugin)

	if !strings.Contains(got, `name="Fix &amp; &quot;Cha&quot; &lt;1&gt;"`) {
		t.Errorf("XML() =\n%s\nwant the escaped name", got)
	}
}
