target_sources(vnote PRIVATE
    exportdata.cpp exportdata.h
    exporter.cpp exporter.h
    exportstylesheet.cpp exportstylesheet.h exportstylesheet.qrc
    exportrenderer.cpp exportrenderer.h
    exportrendererfactory.cpp exportrendererfactory.h
    exportbuiltinrenderers.cpp
    mindmapexporter.cpp mindmapexporter.h
    htmlpdfexporter.cpp htmlpdfexporter.h
    exportfontresolver.cpp exportfontresolver.h
    exportstyleresolver.cpp exportstyleresolver.h
    imgsrcrewriter.cpp imgsrcrewriter.h
    webviewexporter.cpp webviewexporter.h
    wkhtmltopdfhtmlpatch.cpp wkhtmltopdfhtmlpatch.h
)

# The Typst exporter renders through the native Qt 6 typst stack and is
# excluded from the Qt 5.15 / Windows 7 variant.
if(VTEXTEDIT_ENABLE_TYPST)
    target_sources(vnote PRIVATE
        typstexporter.cpp typstexporter.h
    )
endif()
