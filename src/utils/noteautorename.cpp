#include "noteautorename.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStringList>

#include "pathutils.h"

using namespace vnotex;

namespace {
constexpr int c_maxBaseNameLength = 120;

bool isDefaultBaseName(const QString &p_base) {
  if (p_base.isEmpty()) {
    return false;
  }

  QStringList stems;
  stems << QStringLiteral("note") << QString::fromUtf8("\xE7\xAC\x94\xE8\xAE\xB0");
  const QString translated =
      QCoreApplication::translate("vnotex::NewNoteDialog2", "note").trimmed();
  if (!translated.isEmpty()) {
    bool already = false;
    for (const auto &stem : stems) {
      if (stem.compare(translated, Qt::CaseInsensitive) == 0) {
        already = true;
        break;
      }
    }
    if (!already) {
      stems << translated;
    }
  }

  QStringList escaped;
  escaped.reserve(stems.size());
  for (const auto &stem : stems) {
    escaped << QRegularExpression::escape(stem);
  }

  const QRegularExpression re(QStringLiteral("^(%1)(_?\\d+)?$").arg(escaped.join(QLatin1Char('|'))),
                              QRegularExpression::CaseInsensitiveOption);
  return re.match(p_base).hasMatch();
}

QString fileBaseName(const QString &p_fileName) {
  const QString name = QFileInfo(p_fileName).fileName();
  return QFileInfo(name).completeBaseName();
}

QString fileSuffix(const QString &p_fileName) { return QFileInfo(p_fileName).suffix(); }

bool isHorizontalRule(const QString &p_line) {
  static const QRegularExpression re(QStringLiteral("^(\\*{3,}|-{3,}|_{3,})$"));
  return re.match(p_line).hasMatch();
}
} // namespace

bool NoteAutoRename::isDefaultNoteName(const QString &p_fileName) {
  return isDefaultBaseName(fileBaseName(p_fileName));
}

QString NoteAutoRename::firstMeaningfulLine(const QString &p_content) {
  const QStringList lines = p_content.split(QLatin1Char('\n'));
  int i = 0;
  // A leading --- is YAML front matter only when a closer exists; otherwise it
  // is just a horizontal rule and must not swallow the rest of the note.
  if (!lines.isEmpty() && lines[0].trimmed() == QLatin1String("---")) {
    int closer = -1;
    for (int j = 1; j < lines.size(); ++j) {
      const QString trimmed = lines[j].trimmed();
      if (trimmed == QLatin1String("---") || trimmed == QLatin1String("...")) {
        closer = j;
        break;
      }
    }
    i = (closer >= 0) ? (closer + 1) : 1;
  }

  static const QRegularExpression headingPrefix(QStringLiteral("^#{1,6}\\s*"));
  static const QRegularExpression headingSuffix(QStringLiteral("\\s+#+$"));

  for (; i < lines.size(); ++i) {
    QString line = lines[i].trimmed();
    if (line.isEmpty() || isHorizontalRule(line)) {
      continue;
    }

    line.remove(headingPrefix);
    line.remove(headingSuffix);
    line = line.trimmed();
    if (!line.isEmpty()) {
      return line;
    }
  }
  return QString();
}

QString NoteAutoRename::sanitizeBaseName(const QString &p_title) {
  QString out;
  out.reserve(p_title.size());
  for (const QChar ch : p_title) {
    const ushort uc = ch.unicode();
    if (uc < 0x20 || ch == QLatin1Char('\\') || ch == QLatin1Char('/') || ch == QLatin1Char(':') ||
        ch == QLatin1Char('*') || ch == QLatin1Char('?') || ch == QLatin1Char('"') ||
        ch == QLatin1Char('<') || ch == QLatin1Char('>') || ch == QLatin1Char('|')) {
      out.append(QLatin1Char(' '));
    } else if (ch.isSpace()) {
      out.append(QLatin1Char(' '));
    } else {
      out.append(ch);
    }
  }

  out = out.simplified();
  while (out.endsWith(QLatin1Char('.'))) {
    out.chop(1);
    out = out.trimmed();
  }

  if (out.size() > c_maxBaseNameLength) {
    out = out.left(c_maxBaseNameLength).trimmed();
  }

  if (out.isEmpty() || !PathUtils::isLegalFileName(out)) {
    return QString();
  }
  return out;
}

QString NoteAutoRename::suggestedFileName(const QString &p_currentFileName,
                                          const QString &p_content) {
  if (!isDefaultNoteName(p_currentFileName)) {
    return QString();
  }

  const QString base = sanitizeBaseName(firstMeaningfulLine(p_content));
  if (base.isEmpty() || isDefaultBaseName(base)) {
    return QString();
  }

  const QString currentBase = fileBaseName(p_currentFileName);
  if (base.compare(currentBase, Qt::CaseInsensitive) == 0) {
    return QString();
  }

  const QString suffix = fileSuffix(p_currentFileName);
  if (suffix.isEmpty()) {
    return base;
  }
  return base + QLatin1Char('.') + suffix;
}
