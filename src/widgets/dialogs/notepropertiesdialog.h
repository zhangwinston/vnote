#ifndef NOTEPROPERTIESDIALOG_H
#define NOTEPROPERTIESDIALOG_H

#include "scrolldialog.h"

namespace vnotex {
class Node;
class NodeInfoWidget;

class NotePropertiesDialog : public ScrollDialog {
  Q_OBJECT
public:
  NotePropertiesDialog(Node *p_node, QWidget *p_parent = nullptr);
  NotePropertiesDialog(Node *p_node, QWidget *p_parent, QString newName);

protected:
  void acceptedButtonClicked() Q_DECL_OVERRIDE;

private:
  void setupUI();
  void setupUI(QString newName);

  void setupNodeInfoWidget(QWidget *p_parent);
  void setupNodeInfoWidget(QWidget *p_parent, QString newName);

  bool validateNameInput(QString &p_msg);

  bool saveNoteProperties();

  bool validateInputs();

  NodeInfoWidget *m_infoWidget = nullptr;

  Node *m_node = nullptr;
};
} // namespace vnotex

#endif // NOTEPROPERTIESDIALOG_H
