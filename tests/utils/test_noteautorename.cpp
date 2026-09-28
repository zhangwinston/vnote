#include <QtTest>

#include <utils/noteautorename.h>

using namespace vnotex;

namespace tests {

class TestNoteAutoRename : public QObject {
  Q_OBJECT

private slots:
  void defaultNoteName_data();
  void defaultNoteName();

  void firstMeaningfulLine_data();
  void firstMeaningfulLine();

  void sanitizeBaseName_data();
  void sanitizeBaseName();

  void suggestedFileName_data();
  void suggestedFileName();
};

void TestNoteAutoRename::defaultNoteName_data() {
  QTest::addColumn<QString>("name");
  QTest::addColumn<bool>("expected");

  QTest::newRow("note") << QStringLiteral("note") << true;
  QTest::newRow("note.md") << QStringLiteral("note.md") << true;
  QTest::newRow("Note.MD") << QStringLiteral("Note.MD") << true;
  QTest::newRow("note1") << QStringLiteral("note1") << true;
  QTest::newRow("note_1.md") << QStringLiteral("note_1.md") << true;
  QTest::newRow("note_12.md") << QStringLiteral("note_12.md") << true;
  QTest::newRow("note2.md") << QStringLiteral("note2.md") << true;
  QTest::newRow("biji") << QString::fromUtf8("\xE7\xAC\x94\xE8\xAE\xB0") << true;
  QTest::newRow("biji.md") << QString::fromUtf8("\xE7\xAC\x94\xE8\xAE\xB0.md") << true;
  QTest::newRow("biji1") << QString::fromUtf8("\xE7\xAC\x94\xE8\xAE\xB0" "1") << true;
  QTest::newRow("biji_1.md") << QString::fromUtf8("\xE7\xAC\x94\xE8\xAE\xB0_1.md") << true;
  QTest::newRow("diary") << QString::fromUtf8("\xE6\x97\xA5\xE8\xAE\xB0.md") << false;
  QTest::newRow("note-extra") << QStringLiteral("note-extra.md") << false;
  QTest::newRow("my note") << QStringLiteral("my note.md") << false;
  QTest::newRow("empty") << QString() << false;
}

void TestNoteAutoRename::defaultNoteName() {
  QFETCH(QString, name);
  QFETCH(bool, expected);
  QCOMPARE(NoteAutoRename::isDefaultNoteName(name), expected);
}

void TestNoteAutoRename::firstMeaningfulLine_data() {
  QTest::addColumn<QString>("content");
  QTest::addColumn<QString>("expected");

  QTest::newRow("plain") << QStringLiteral("Hello world\nmore") << QStringLiteral("Hello world");
  QTest::newRow("leading blanks") << QStringLiteral("  \n\n  Title  \nbody")
                                  << QStringLiteral("Title");
  QTest::newRow("heading") << QStringLiteral("# My Title\nbody") << QStringLiteral("My Title");
  QTest::newRow("h2 trailing hashes")
      << QStringLiteral("## Title ##\nbody") << QStringLiteral("Title");
  QTest::newRow("front matter") << QStringLiteral("---\ntitle: x\n---\n\n# Real Title\n")
                                << QStringLiteral("Real Title");
  QTest::newRow("hr then title") << QStringLiteral("---\n***\nActual\n")
                                 << QStringLiteral("Actual");
  QTest::newRow("unclosed fence is hr")
      << QStringLiteral("---\n# Still A Title\n") << QStringLiteral("Still A Title");
  QTest::newRow("empty") << QStringLiteral("  \n\n") << QString();
  QTest::newRow("heading only hashes") << QStringLiteral("##  \nbody") << QStringLiteral("body");
}

void TestNoteAutoRename::firstMeaningfulLine() {
  QFETCH(QString, content);
  QFETCH(QString, expected);
  QCOMPARE(NoteAutoRename::firstMeaningfulLine(content), expected);
}

void TestNoteAutoRename::sanitizeBaseName_data() {
  QTest::addColumn<QString>("title");
  QTest::addColumn<QString>("expected");

  QTest::newRow("plain") << QStringLiteral("Hello") << QStringLiteral("Hello");
  QTest::newRow("illegal") << QStringLiteral("a/b:c*d") << QStringLiteral("a b c d");
  QTest::newRow("spaces") << QStringLiteral("  foo   bar  ") << QStringLiteral("foo bar");
  QTest::newRow("trailing dots") << QStringLiteral("name...") << QStringLiteral("name");
  QTest::newRow("empty after strip") << QStringLiteral("***") << QString();
}

void TestNoteAutoRename::sanitizeBaseName() {
  QFETCH(QString, title);
  QFETCH(QString, expected);
  QCOMPARE(NoteAutoRename::sanitizeBaseName(title), expected);
}

void TestNoteAutoRename::suggestedFileName_data() {
  QTest::addColumn<QString>("current");
  QTest::addColumn<QString>("content");
  QTest::addColumn<QString>("expected");

  QTest::newRow("default plus heading")
      << QStringLiteral("note.md") << QStringLiteral("# Weekly Review\nbody")
      << QStringLiteral("Weekly Review.md");
  QTest::newRow("biji plus first line")
      << QString::fromUtf8("\xE7\xAC\x94\xE8\xAE\xB0_1.md") << QStringLiteral("\n  Meeting notes\n")
      << QStringLiteral("Meeting notes.md");
  QTest::newRow("custom name skipped")
      << QStringLiteral("already.md") << QStringLiteral("# Other") << QString();
  QTest::newRow("empty content skipped")
      << QStringLiteral("note.md") << QStringLiteral("\n\n") << QString();
  QTest::newRow("same as current skipped")
      << QStringLiteral("note.md") << QStringLiteral("note\nbody") << QString();
  QTest::newRow("no suffix") << QStringLiteral("note") << QStringLiteral("Alpha")
                             << QStringLiteral("Alpha");
}

void TestNoteAutoRename::suggestedFileName() {
  QFETCH(QString, current);
  QFETCH(QString, content);
  QFETCH(QString, expected);
  QCOMPARE(NoteAutoRename::suggestedFileName(current, content), expected);
}

} // namespace tests

QTEST_GUILESS_MAIN(tests::TestNoteAutoRename)
#include "test_noteautorename.moc"
