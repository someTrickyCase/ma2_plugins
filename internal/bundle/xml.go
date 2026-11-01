package bundle

import "strings"

const (
	httpScheme  = "http:"
	maSchemas   = httpScheme + "//schemas.malighting.de/grandma2/xml/"
	maNamespace = maSchemas + "MA"
	maSchema    = maSchemas + "3.0.187/MA.xsd"
	xsiSchema   = httpScheme + "//www.w3.org/2001/XMLSchema-instance"
	space       = " "
)

func XML(plugin Plugin) string {
	root := strings.Join([]string{
		"<MA",
		attribute("xmlns:xsi", xsiSchema),
		attribute("xmlns", maNamespace),
		attribute("xsi:schemaLocation", maNamespace+space+maSchema),
		attribute("major_vers", "3"),
		attribute("minor_vers", "0"),
		attribute("stream_vers", "187") + ">",
	}, space)

	info := strings.Join([]string{
		"    <Info",
		attribute("datetime", plugin.Stamp.Date+"T00:00:00"),
		attribute("showfile", plugin.Manifest.File),
		"/>",
	}, space)

	entry := strings.Join([]string{
		"    <Plugin",
		attribute("index", "1"),
		attribute("execute_on_load", "0"),
		attribute("name", plugin.Manifest.Name),
		attribute("luafile", plugin.Manifest.File+".lua"),
		"/>",
	}, space)

	return strings.Join([]string{
		`<?xml version="1.0" encoding="utf-8"?>`,
		root,
		info,
		entry,
		"</MA>",
	}, "\n") + "\n"
}

func attribute(name string, value string) string {
	return name + `="` + escapeXML(value) + `"`
}

func escapeXML(text string) string {
	return strings.NewReplacer(
		"&", "&amp;",
		"<", "&lt;",
		">", "&gt;",
		`"`, "&quot;",
	).Replace(text)
}
