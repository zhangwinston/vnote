#ifndef NOTEAUTORENAME_H
#define NOTEAUTORENAME_H

#include <QString>

namespace vnotex {

// Pure helpers for the "default-named note → first content line" rename flow.
// A note whose basename is the New Note default ("note" / translated "笔记")
// plus an optional numeric suffix (note1, note_1, 笔记2, ...) is treated as
// untitled. On save or close the first meaningful content line is offered as
// the new filename.
class NoteAutoRename {
public:
  NoteAutoRename() = delete;

  // True when @p_fileName (with or without suffix) is a generated default
  // name: "note", "note.md", "note1", "note_1.md", "笔记", "笔记2.md", ...
  static bool isDefaultNoteName(const QString &p_fileName);

  // First non-blank content line, skipping YAML front matter and stripping
  // ATX heading markers. Empty when the note has no usable title line.
  static QString firstMeaningfulLine(const QString &p_content);

  // Turn a title into a legal filename base (no suffix). Empty when nothing
  // usable remains after stripping illegal characters.
  static QString sanitizeBaseName(const QString &p_title);

  // Suggested full filename (original suffix preserved). Empty when the
  // current name is not a default, there is no usable first line, or the
  // suggestion equals the current basename.
  static QString suggestedFileName(const QString &p_currentFileName, const QString &p_content);
};

} // namespace vnotex

#endif // NOTEAUTORENAME_H
