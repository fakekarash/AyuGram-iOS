import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

private func ayuGramHeaderVersionString() -> String {
    return (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
}

private func ayuGramHeaderImage(presentationData: ItemListPresentationData) -> UIImage? {
    let theme = presentationData.theme
    let baseSize = presentationData.fontSize.itemListBaseHeaderFontSize
    let scale = UIScreen.main.scale
    let version = ayuGramHeaderVersionString()

    let size = CGSize(width: 268.0, height: 134.0)
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
        let cgContext = context.cgContext
        let iconSide: CGFloat = 68.0
        let iconRect = CGRect(x: floor((size.width - iconSide) / 2.0), y: 8.0, width: iconSide, height: iconSide)

        let iconPath = UIBezierPath(roundedRect: iconRect, cornerRadius: iconSide * 0.235)
        cgContext.saveGState()
        iconPath.addClip()
        let gradientColors = [
            UIColor(red: 0.51, green: 0.42, blue: 1.00, alpha: 1.0).cgColor,
            UIColor(red: 0.34, green: 0.25, blue: 0.82, alpha: 1.0).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0.0, 1.0]) {
            cgContext.drawLinearGradient(gradient, start: CGPoint(x: iconRect.minX, y: iconRect.minY), end: CGPoint(x: iconRect.maxX, y: iconRect.maxY), options: [])
        }
        cgContext.restoreGState()

        let planeConfiguration = UIImage.SymbolConfiguration(pointSize: 34.0, weight: .medium)
        if let plane = UIImage(systemName: "paperplane.fill", withConfiguration: planeConfiguration)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            let planeSize = plane.size
            plane.draw(in: CGRect(x: iconRect.midX - planeSize.width / 2.0, y: iconRect.midY - planeSize.height / 2.0, width: planeSize.width, height: planeSize.height))
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: floor(baseSize * 1.55), weight: .semibold),
            .foregroundColor: theme.list.itemPrimaryTextColor
        ]
        let title = "AyuGram" as NSString
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: iconRect.maxY + 10.0), withAttributes: titleAttributes)

        let versionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: floor(baseSize * 0.95), weight: .regular),
            .foregroundColor: theme.list.itemSecondaryTextColor
        ]
        let versionString = version as NSString
        let versionSize = versionString.size(withAttributes: versionAttributes)
        versionString.draw(at: CGPoint(x: floor((size.width - versionSize.width) / 2.0), y: iconRect.maxY + 10.0 + titleSize.height + 2.0), withAttributes: versionAttributes)
    }
}

public class AyuGramHeaderItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    public let sectionId: ItemListSectionId
    public let tag: ItemListItemTag?
    public let isAlwaysPlain: Bool = true

    public init(presentationData: ItemListPresentationData, sectionId: ItemListSectionId, tag: ItemListItemTag? = nil) {
        self.presentationData = presentationData
        self.sectionId = sectionId
        self.tag = tag
    }

    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AyuGramHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params)

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? AyuGramHeaderItemNode else {
                return
            }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params)
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

public class AyuGramHeaderItemNode: ListViewItemNode, ItemListItemNode {
    private let imageNode: ASImageNode
    private var item: AyuGramHeaderItem?

    public var tag: ItemListItemTag? {
        return self.item?.tag
    }

    public init() {
        self.imageNode = ASImageNode()
        self.imageNode.contentMode = .center
        self.imageNode.isUserInteractionEnabled = false
        super.init(layerBacked: false)
        self.addSubnode(self.imageNode)
    }

    public func asyncLayout() -> (_ item: AyuGramHeaderItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params in
            let image = ayuGramHeaderImage(presentationData: item.presentationData)
            let imageSize = image?.size ?? CGSize(width: 1.0, height: 134.0)
            let contentSize = CGSize(width: max(params.width, imageSize.width), height: imageSize.height)
            let insets = UIEdgeInsets(top: 12.0, left: 0.0, bottom: 6.0, right: 0.0)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)

            return (layout, {
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.imageNode.image = image
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                }
            })
        }
    }
}
