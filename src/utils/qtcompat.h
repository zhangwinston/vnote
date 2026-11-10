#ifndef VNOTE_QTCOMPAT_H
#define VNOTE_QTCOMPAT_H

#include <QFileInfo>
#include <QFuture>
#include <QMouseEvent>
#include <QObject>
#include <QWheelEvent>
#include <QtGlobal>

#include <memory>
#include <utility>

// The QFormLayout helper below needs QtWidgets headers. core_services includes
// this file without linking Qt::Widgets, so gate the include (and the helper)
// on the module define Qt sets for every target that links the module.
#ifdef QT_WIDGETS_LIB
#include <QFormLayout>
#include <QWidget>
#endif

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
#include <QByteArrayView>
#include <QEnterEvent>
#else
#include <QByteArray>
#include <QEvent>
#endif

namespace vnotex {

// Type alias for the buffer view type. On Qt6 this is a non-owning
// QByteArrayView; on Qt5 we fall back to QByteArray (cheap COW) since
// QByteArrayView does not exist. Both are convertible to QString::fromUtf8.
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
using QByteArrayViewCompat = QByteArrayView;
#else
using QByteArrayViewCompat = QByteArray;
#endif

// Type alias for the parameter type of QWidget::enterEvent.
// Qt6 introduced QEnterEvent; Qt5 still uses QEvent here.
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
using EnterEventCompat = QEnterEvent;
#else
using EnterEventCompat = QEvent;
#endif

// QFileInfo::isSymbolicLink()/isJunction() are Qt 6 only. Qt 5's isSymLink()
// reports symbolic links and, on Windows, junctions, so it stands in for the
// pair; a separate junction probe does not exist there.
inline bool fileInfoIsSymbolicLink(const QFileInfo &p_info) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return p_info.isSymbolicLink();
#else
  return p_info.isSymLink();
#endif
}

inline bool fileInfoIsJunction(const QFileInfo &p_info) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return p_info.isJunction();
#else
  return false;
#endif
}

// QMouseEvent/QWheelEvent::position() (QPointF) and QMouseEvent::globalPosition()
// are Qt 6 only; Qt 5 has pos()/globalPos() (QPoint).
inline QPoint eventPosition(const QMouseEvent &p_event) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return p_event.position().toPoint();
#else
  return p_event.pos();
#endif
}

inline QPoint eventPosition(const QWheelEvent &p_event) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return p_event.position().toPoint();
#else
  return p_event.pos();
#endif
}

inline QPoint eventGlobalPosition(const QMouseEvent &p_event) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return p_event.globalPosition().toPoint();
#else
  return p_event.globalPos();
#endif
}

// QFormLayout::setRowVisible is Qt 6.4+; Qt 5 hides the row's label and field.
#ifdef QT_WIDGETS_LIB
inline void formLayoutSetRowVisible(QFormLayout *p_layout, QWidget *p_field, bool p_visible) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 4, 0)
  p_layout->setRowVisible(p_field, p_visible);
#else
  if (auto *label = p_layout->labelForField(p_field)) {
    label->setVisible(p_visible);
  }
  p_field->setVisible(p_visible);
#endif
}
#endif // QT_WIDGETS_LIB

// QFuture::takeResult() is Qt 6 only. Qt 5 falls back to a copy; callers that
// delete the watcher right after still release the stored result immediately.
template <typename T> T futureTakeResult(QFuture<T> p_future) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return p_future.takeResult();
#else
  return p_future.result();
#endif
}

// Qt::SingleShotConnection is Qt 6 only. The Qt 5 branch self-disconnects on
// first delivery; the shared holder is released when the connection (and with
// it the lambda) is destroyed, whether or not the signal ever fired.
template <typename Sender, typename Signal, typename Context, typename Functor>
QMetaObject::Connection connectSingleShot(Sender &&p_sender, Signal &&p_signal, Context &&p_context,
                                          Functor &&p_functor,
                                          Qt::ConnectionType p_type = Qt::AutoConnection) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return QObject::connect(std::forward<Sender>(p_sender), std::forward<Signal>(p_signal),
                          std::forward<Context>(p_context), std::forward<Functor>(p_functor),
                          static_cast<Qt::ConnectionType>(p_type | Qt::SingleShotConnection));
#else
  auto connection = std::make_shared<QMetaObject::Connection>();
  *connection = QObject::connect(
      std::forward<Sender>(p_sender), std::forward<Signal>(p_signal),
      std::forward<Context>(p_context),
      [functor = std::forward<Functor>(p_functor), connection]() mutable {
        QObject::disconnect(*connection);
        functor();
      },
      p_type);
  return *connection;
#endif
}

} // namespace vnotex

#endif // VNOTE_QTCOMPAT_H
