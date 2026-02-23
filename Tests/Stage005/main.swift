import Foundation

struct Stage005TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

struct SemanticBox: Equatable {
    let label: String
    let xMin: Double
    let yMin: Double
    let xMax: Double
    let yMax: Double

    init(_ box: AnnotationBoundingBox) {
        label = box.label
        xMin = box.xMin
        yMin = box.yMin
        xMax = box.xMax
        yMax = box.yMax
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw Stage005TestFailure(message: message)
    }
}

func requireEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw Stage005TestFailure(message: "\(message)\nExpected: \(expected)\nActual: \(actual)")
    }
}

func readTrimmedText(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func copyFixture(_ name: String, from fixturesRoot: URL, to destinationURL: URL) throws {
    let sourceURL = fixturesRoot.appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
}

func testPascalVOCRoundtrip(fixturesRoot: URL, tempRoot: URL) throws {
    let testDir = tempRoot.appendingPathComponent("pascal-roundtrip", isDirectory: true)
    try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

    let imageURL = testDir.appendingPathComponent("fixture-image.png")
    let xmlURL = testDir.appendingPathComponent("fixture-image.xml")
    try copyFixture("fixture-image.png", from: fixturesRoot, to: imageURL)
    try copyFixture("pascal-voc-sample.xml", from: fixturesRoot, to: xmlURL)

    let loaded = try PascalVOCStore.loadDocument(for: imageURL)
    try requireEqual(loaded.filename, "fixture-image.png", "Pascal VOC filename parse failed")
    try requireEqual(loaded.imageSize.width, 640, "Pascal VOC width parse failed")
    try requireEqual(loaded.imageSize.height, 480, "Pascal VOC height parse failed")
    try requireEqual(loaded.imageSize.depth, 3, "Pascal VOC depth parse failed")
    try requireEqual(loaded.objects.count, 2, "Pascal VOC object count parse failed")

    let before = loaded.objects.map(SemanticBox.init)
    try PascalVOCStore.write(document: loaded)
    let roundtrip = try PascalVOCStore.loadDocument(for: imageURL)
    let after = roundtrip.objects.map(SemanticBox.init)

    try requireEqual(before, after, "Pascal VOC parse/write roundtrip changed bounding boxes")
    try requireEqual(roundtrip.imageSize, loaded.imageSize, "Pascal VOC roundtrip changed image size")
    try requireEqual(roundtrip.filename, loaded.filename, "Pascal VOC roundtrip changed filename")

    print("PASS Pascal VOC parse/write roundtrip")
}

func testYOLOMath(fixturesRoot: URL, tempRoot: URL) throws {
    let testDir = tempRoot.appendingPathComponent("yolo-math", isDirectory: true)
    try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

    let imageURL = testDir.appendingPathComponent("yolo-math.png")
    try copyFixture("fixture-image.png", from: fixturesRoot, to: imageURL)

    let document = ImageAnnotationDocument(
        imageURL: imageURL,
        filename: "yolo-math.png",
        imageSize: AnnotationImageSize(width: 640, height: 480, depth: 3),
        objects: [
            AnnotationBoundingBox(label: "dog", xMin: 64, yMin: 48, xMax: 320, yMax: 240),
            AnnotationBoundingBox(label: "cat", xMin: -10, yMin: 240, xMax: 650, yMax: 600)
        ],
        isDirty: true,
        loadedFromXML: false
    )

    try YOLOStore.write(document: document, classes: ["cat", "dog"])

    let expectedURL = fixturesRoot.appendingPathComponent("yolo-expected.txt")
    let actual = try readTrimmedText(document.yoloURL)
    let expected = try readTrimmedText(expectedURL)
    try requireEqual(actual, expected, "YOLO conversion output did not match fixture")

    print("PASS YOLO conversion math fixture")
}

func testClassesDeterministicMapping(fixturesRoot: URL, tempRoot: URL) throws {
    let testDir = tempRoot.appendingPathComponent("classes-merge", isDirectory: true)
    try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

    let classesURL = testDir.appendingPathComponent("classes.txt")
    try copyFixture("classes-initial.txt", from: fixturesRoot, to: classesURL)

    let merged = try ClassesFileStore.loadAndMergeClasses(
        rootDirectory: testDir,
        adding: Set(["Dog", "ant", "cat"])
    )

    let expectedText = try readTrimmedText(fixturesRoot.appendingPathComponent("classes-expected.txt"))
    let actualText = try readTrimmedText(classesURL)
    try requireEqual(actualText, expectedText, "classes.txt merge output did not match fixture")
    try requireEqual(merged, expectedText.components(separatedBy: "\n"), "Merged class list order mismatch")

    let secondMerge = try ClassesFileStore.loadAndMergeClasses(
        rootDirectory: testDir,
        adding: Set(["Dog", "ant", "cat"])
    )
    let actualTextAfterSecondMerge = try readTrimmedText(classesURL)
    try requireEqual(actualTextAfterSecondMerge, expectedText, "classes.txt merge should be idempotent")
    try requireEqual(secondMerge, merged, "Repeated merge should preserve class IDs/order")

    print("PASS classes.txt deterministic merge fixture")
}

do {
    guard CommandLine.arguments.count >= 2 else {
        throw Stage005TestFailure(message: "Usage: Stage005ValidationRunner <repo-root>")
    }

    let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let fixturesRoot = repoRoot.appendingPathComponent("Tests/Fixtures/Stage005", isDirectory: true)
    try require(FileManager.default.fileExists(atPath: fixturesRoot.path), "Missing fixtures directory: \(fixturesRoot.path)")

    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ImageAnnotationTool-Stage005-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try testPascalVOCRoundtrip(fixturesRoot: fixturesRoot, tempRoot: tempRoot)
    try testYOLOMath(fixturesRoot: fixturesRoot, tempRoot: tempRoot)
    try testClassesDeterministicMapping(fixturesRoot: fixturesRoot, tempRoot: tempRoot)

    print("PASS Stage 005 validation suite")
} catch {
    fputs("FAIL Stage 005 validation suite: \(error)\n", stderr)
    Foundation.exit(1)
}
