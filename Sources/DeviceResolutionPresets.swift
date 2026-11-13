import Foundation

enum PresetDeviceCategory: String, CaseIterable, Identifiable {
    case ipad = "iPad"
    case iphone = "iPhone"
    var id: String { rawValue }
}

struct DeviceResolutionPreset: Identifiable {
    let id: String
    let name: String
    let category: PresetDeviceCategory
    let resolution: CanvasResolution

    private static func make(
        _ category: PresetDeviceCategory,
        _ names: [String],
        _ width: Int,
        _ height: Int
    ) -> [DeviceResolutionPreset] {
        names.map { name in
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            return DeviceResolutionPreset(
                id: "\(slug)-\(width)x\(height)",
                name: name,
                category: category,
                resolution: CanvasResolution(width: width, height: height)
            )
        }
    }

    static let all: [DeviceResolutionPreset] = {
        var values: [DeviceResolutionPreset] = []

        func add(_ category: PresetDeviceCategory, _ names: [String], _ width: Int, _ height: Int) {
            values.append(contentsOf: make(category, names, width, height))
        }

        // iPhone models, newest release first. All ordinary iPhone presets are portrait.
        add(.iphone, ["iPhone Duo (inner display)"], 1878, 2670)
        add(.iphone, ["iPhone Duo (outer display)"], 1398, 2034)
        add(.iphone, ["iPhone 18 Pro Max"], 1320, 2868)
        add(.iphone, ["iPhone 18 Pro"], 1206, 2622)
        add(.iphone, ["iPhone 17 Pro Max"], 1320, 2868)
        add(.iphone, ["iPhone 17 Pro", "iPhone 17"], 1206, 2622)
        add(.iphone, ["iPhone 17e"], 1170, 2532)
        add(.iphone, ["iPhone Air"], 1260, 2736)

        add(.iphone, ["iPhone 16 Pro Max"], 1320, 2868)
        add(.iphone, ["iPhone 16 Pro"], 1206, 2622)
        add(.iphone, ["iPhone 16 Plus"], 1290, 2796)
        add(.iphone, ["iPhone 16"], 1179, 2556)
        add(.iphone, ["iPhone 16e"], 1170, 2532)

        add(.iphone, ["iPhone 15 Pro Max", "iPhone 15 Plus"], 1290, 2796)
        add(.iphone, ["iPhone 15 Pro", "iPhone 15"], 1179, 2556)

        add(.iphone, ["iPhone 14 Pro Max"], 1290, 2796)
        add(.iphone, ["iPhone 14 Pro"], 1179, 2556)
        add(.iphone, ["iPhone 14 Plus"], 1284, 2778)
        add(.iphone, ["iPhone 14"], 1170, 2532)

        add(.iphone, ["iPhone 13 Pro Max", "iPhone 12 Pro Max"], 1284, 2778)
        add(.iphone, ["iPhone 13 Pro", "iPhone 13"], 1170, 2532)
        add(.iphone, ["iPhone 13 mini", "iPhone 12 mini"], 1080, 2340)
        add(.iphone, ["iPhone 12 Pro", "iPhone 12"], 1170, 2532)

        add(.iphone, ["iPhone 11 Pro Max", "iPhone XS Max"], 1242, 2688)
        add(.iphone, ["iPhone 11 Pro", "iPhone XS", "iPhone X"], 1125, 2436)
        add(.iphone, ["iPhone 11", "iPhone XR"], 828, 1792)

        add(.iphone, ["iPhone 8 Plus", "iPhone 7 Plus", "iPhone 6s Plus", "iPhone 6 Plus"], 1080, 1920)
        add(.iphone, ["iPhone SE (3rd generation)", "iPhone SE (2nd generation)",
                      "iPhone 8", "iPhone 7", "iPhone 6s", "iPhone 6"], 750, 1334)
        add(.iphone, ["iPhone SE (1st generation)", "iPhone 5s", "iPhone 5c", "iPhone 5"], 640, 1136)
        add(.iphone, ["iPhone 4s", "iPhone 4"], 640, 960)
        add(.iphone, ["iPhone 3GS", "iPhone 3G", "iPhone (1st generation)"], 320, 480)

        // iPad models, newest release first. All iPad presets are landscape.
        add(.ipad, ["iPad Pro 13-inch (M5)"], 2752, 2064)
        add(.ipad, ["iPad Pro 11-inch (M5)"], 2420, 1668)
        add(.ipad, ["iPad Air 13-inch (M4)"], 2732, 2048)
        add(.ipad, ["iPad Air 11-inch (M4)"], 2360, 1640)
        add(.ipad, ["iPad mini (A20 Pro)"], 2316, 1512)
        add(.ipad, ["iPad (A16)"], 2360, 1640)

        add(.ipad, ["iPad Pro 13-inch (M4)"], 2752, 2064)
        add(.ipad, ["iPad Pro 11-inch (M4)"], 2420, 1668)
        add(.ipad, ["iPad Air 13-inch (M3)", "iPad Air 13-inch (M2)"], 2732, 2048)
        add(.ipad, ["iPad Air 11-inch (M3)", "iPad Air 11-inch (M2)",
                    "iPad Air (5th generation)", "iPad Air (4th generation)",
                    "iPad (10th generation)"], 2360, 1640)
        add(.ipad, ["iPad mini (A17 Pro)", "iPad mini 6"], 2266, 1488)

        add(.ipad, ["iPad Pro 12.9-inch (6th generation)",
                    "iPad Pro 12.9-inch (5th generation)",
                    "iPad Pro 12.9-inch (4th generation)",
                    "iPad Pro 12.9-inch (3rd generation)",
                    "iPad Pro 12.9-inch (2nd generation)",
                    "iPad Pro 12.9-inch (1st generation)"], 2732, 2048)
        add(.ipad, ["iPad Pro 11-inch (4th generation)",
                    "iPad Pro 11-inch (3rd generation)",
                    "iPad Pro 11-inch (2nd generation)",
                    "iPad Pro 11-inch (1st generation)"], 2388, 1668)
        add(.ipad, ["iPad Pro 10.5-inch", "iPad Air (3rd generation)"], 2224, 1668)

        add(.ipad, ["iPad (9th generation)", "iPad (8th generation)", "iPad (7th generation)"], 2160, 1620)
        add(.ipad, ["iPad mini 5", "iPad mini 4", "iPad mini 3", "iPad mini 2",
                    "iPad Air 2", "iPad Air (1st generation)",
                    "iPad (6th generation)", "iPad (5th generation)"], 2048, 1536)
        add(.ipad, ["iPad mini (1st generation)", "iPad 2", "iPad (1st generation)"], 1024, 768)

        return values
    }()
}
