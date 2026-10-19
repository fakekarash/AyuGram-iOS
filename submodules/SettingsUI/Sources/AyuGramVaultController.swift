import Foundation
import UIKit
import QuickLook
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import AlertUI

private final class AyuGramVaultPreviewController: QLPreviewController, QLPreviewControllerDataSource {
    private let previewURL: URL

    init(url: URL) {
        self.previewURL = url
        super.init(nibName: nil, bundle: nil)
        self.dataSource = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.previewURL as NSURL
    }
}

private final class AyuGramVaultControllerArguments {
    let open: (AyuGramVaultItem) -> Void
    let openArchive: (AyuGramArchiveRecord) -> Void
    let clearAll: () -> Void

    init(open: @escaping (AyuGramVaultItem) -> Void, openArchive: @escaping (AyuGramArchiveRecord) -> Void, clearAll: @escaping () -> Void) {
        self.open = open
        self.openArchive = openArchive
        self.clearAll = clearAll
    }
}

private final class AyuGramVaultControllerHolder {
    weak var controller: ItemListController?
}

private enum AyuGramVaultSection: Int32 {
    case summary
    case files
    case archive
    case actions
}

private enum AyuGramVaultEntry: ItemListNodeEntry {
    case summary(String)
    case empty
    case file(Int32, AyuGramVaultItem, String)
    case archiveHeader
    case archive(Int32, AyuGramArchiveRecord, String)
    case clearAll

    var section: ItemListSectionId {
        switch self {
        case .summary:
            return AyuGramVaultSection.summary.rawValue
        case .empty, .file:
            return AyuGramVaultSection.files.rawValue
        case .archiveHeader, .archive:
            return AyuGramVaultSection.archive.rawValue
        case .clearAll:
            return AyuGramVaultSection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .summary:
            return 0
        case .empty:
            return 1
        case let .file(index, _, _):
            return 100 + index
        case .archiveHeader:
            return 10_000
        case let .archive(index, _, _):
            return 10_100 + index
        case .clearAll:
            return Int32.max
        }
    }

    static func < (lhs: AyuGramVaultEntry, rhs: AyuGramVaultEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramVaultControllerArguments
        switch self {
        case let .summary(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Хранилище пока пусто. Откройте одноразовое медиа и нажмите «Сохранить в AyuGram»."), sectionId: self.section)
        case let .file(_, item, title):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: .generic,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { arguments.open(item) }
            )
        case .archiveHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "АРХИВ СООБЩЕНИЙ", sectionId: self.section)
        case let .archive(_, record, title):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: .generic,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { arguments.openArchive(record) }
            )
        case .clearAll:
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Очистить хранилище",
                kind: .destructive,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: arguments.clearAll
            )
        }
    }
}

private func ayuGramVaultEntries() -> [AyuGramVaultEntry] {
    let items = AyuGramVaultStore.items()
    let records = AyuGramArchiveStore.records()
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file

    var result: [AyuGramVaultEntry] = [
        .summary("Файлов: \(items.count) · \(formatter.string(fromByteCount: items.reduce(0) { $0 + $1.byteCount }))\nЗаписей сообщений: \(records.count)\nВсе данные находятся только на этом устройстве.")
    ]
    if items.isEmpty && records.isEmpty {
        result.append(.empty)
    } else if !items.isEmpty {
        for (index, item) in items.enumerated() {
            let name = item.originalFilename ?? item.storedFilename
            let size = formatter.string(fromByteCount: item.byteCount)
            result.append(.file(Int32(index), item, "\(item.kind.title): \(name) · \(size)"))
        }
    }
    if !records.isEmpty {
        result.append(.archiveHeader)
        for (index, record) in records.enumerated() {
            let normalized = record.text.replacingOccurrences(of: "\n", with: " ")
            let preview = normalized.isEmpty ? "медиа или сообщение без текста" : String(normalized.prefix(72))
            let kind = record.isDeleted ? "Удалено" : "Изменено"
            result.append(.archive(Int32(index), record, "\(kind): \(preview)"))
        }
    }
    if !items.isEmpty || !records.isEmpty {
        result.append(.clearAll)
    }
    return result
}

public func ayuGramVaultController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int32>(0, ignoreRepeated: false)
    let revisionValue = Atomic<Int32>(value: 0)
    let controllerHolder = AyuGramVaultControllerHolder()

    let refresh: () -> Void = {
        revision.set(revisionValue.modify { $0 + 1 })
    }

    let arguments = AyuGramVaultControllerArguments(open: { item in
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let title = item.originalFilename ?? item.storedFilename
        let details = "\(item.kind.title)\n\(formatter.string(fromByteCount: item.byteCount))"
        let alert = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: title,
            text: details,
            actions: [
                TextAlertAction(type: .defaultAction, title: "Просмотреть", action: {
                    Queue.mainQueue().after(0.2) {
                        guard FileManager.default.fileExists(atPath: item.fileURL.path) else {
                            return
                        }
                        let preview = AyuGramVaultPreviewController(url: item.fileURL)
                        controllerHolder.controller?.present(preview, animated: true, completion: nil)
                    }
                }),
                TextAlertAction(type: .genericAction, title: "Поделиться", action: {
                    Queue.mainQueue().after(0.2) {
                        let share = UIActivityViewController(activityItems: [item.fileURL], applicationActivities: nil)
                        if let popover = share.popoverPresentationController, let view = controllerHolder.controller?.view {
                            popover.sourceView = view
                            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1.0, height: 1.0)
                        }
                        controllerHolder.controller?.present(share, animated: true, completion: nil)
                    }
                }),
                TextAlertAction(type: .destructiveAction, title: "Удалить", action: {
                    AyuGramVaultStore.remove(item)
                    refresh()
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
            ]
        )
        controllerHolder.controller?.present(alert, in: .window(.root))
    }, openArchive: { record in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        var lines: [String] = []
        if record.isDeleted {
            lines.append("Удалено: " + dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(record.deletionTimestamp))))
        }
        lines.append("Текущий текст:\n" + (record.text.isEmpty ? "[без текста]" : record.text))
        if !record.previousTexts.isEmpty {
            lines.append("Предыдущие версии:")
            for (index, text) in record.previousTexts.enumerated() {
                lines.append("\(index + 1). " + (text.isEmpty ? "[без текста]" : text))
            }
        }
        let alert = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: record.isDeleted ? "Удалённое сообщение" : "История изменений",
            text: lines.joined(separator: "\n\n"),
            actions: [
                TextAlertAction(type: .defaultAction, title: "Копировать", action: {
                    UIPasteboard.general.string = lines.joined(separator: "\n\n")
                }),
                TextAlertAction(type: .destructiveAction, title: "Удалить запись", action: {
                    AyuGramArchiveStore.remove(record)
                    refresh()
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
            ]
        )
        controllerHolder.controller?.present(alert, in: .window(.root))
    }, clearAll: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let alert = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: "Очистить хранилище AyuGram?",
            text: "Все сохранённые медиа, удалённые сообщения и история изменений будут удалены с этого устройства.",
            actions: [
                TextAlertAction(type: .destructiveAction, title: "Очистить", action: {
                    AyuGramVaultStore.removeAll()
                    AyuGramArchiveStore.removeAll()
                    refresh()
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
            ]
        )
        controllerHolder.controller?.present(alert, in: .window(.root))
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let itemPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(
            presentationData: itemPresentationData,
            title: .text("Хранилище AyuGram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: itemPresentationData,
            entries: ayuGramVaultEntries(),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let result = ItemListController(context: context, state: signal)
    controllerHolder.controller = result
    return result
}
