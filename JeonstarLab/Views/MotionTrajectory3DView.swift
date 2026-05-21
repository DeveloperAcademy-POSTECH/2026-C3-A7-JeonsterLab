//
//  MotionTrajectory3DView.swift
//  Wrist Motion
//

import SwiftUI
import SceneKit

struct MotionTrajectory3DView: View {
    let samples: [MotionSample]
    let kind: MotionTrajectoryKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SceneView(
                scene: MotionTrajectorySceneBuilder.makeScene(
                    samples: samples,
                    kind: kind
                ),
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("화면을 드래그하면 3D 그래프를 회전해서 볼 수 있습니다.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

enum MotionTrajectoryKind {
    case userAcceleration
    case gyroscope
    case attitude

    var title: String {
        switch self {
        case .userAcceleration:
            return "User Acceleration"
        case .gyroscope:
            return "Gyroscope"
        case .attitude:
            return "Attitude"
        }
    }

    var description: String {
        switch self {
        case .userAcceleration:
            return "X/Y/Z 사용자 가속도 값을 3D 공간의 궤적으로 표현합니다."
        case .gyroscope:
            return "X/Y/Z 회전 속도 값을 3D 공간의 궤적으로 표현합니다."
        case .attitude:
            return "Roll/Pitch/Yaw 자세 값을 3D 공간의 궤적으로 표현합니다."
        }
    }

    func point(from sample: MotionSample) -> SCNVector3 {
        switch self {
        case .userAcceleration:
            return SCNVector3(
                Float(sample.userAccX),
                Float(sample.userAccY),
                Float(sample.userAccZ)
            )
        case .gyroscope:
            return SCNVector3(
                Float(sample.rotationRateX),
                Float(sample.rotationRateY),
                Float(sample.rotationRateZ)
            )
        case .attitude:
            return SCNVector3(
                Float(sample.attitudeRoll),
                Float(sample.attitudePitch),
                Float(sample.attitudeYaw)
            )
        }
    }
}

enum MotionTrajectorySceneBuilder {
    static func makeScene(samples: [MotionSample], kind: MotionTrajectoryKind) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.systemBackground

        let root = SCNNode()
        scene.rootNode.addChildNode(root)

        let rawPoints = samples.map { kind.point(from: $0) }
        let normalizedPoints = normalize(points: rawPoints)

        addAxes(to: root)
        addTrajectory(points: normalizedPoints, to: root)
        addStartEndMarkers(points: normalizedPoints, to: root)
        addTitle(kind.title, to: root)
        addCamera(to: scene)
        addLight(to: scene)

        return scene
    }

    private static func normalize(points: [SCNVector3]) -> [SCNVector3] {
        guard !points.isEmpty else { return [] }

        let maxAbsValue = points.reduce(Float(0)) { current, point in
            max(
                current,
                abs(point.x),
                abs(point.y),
                abs(point.z)
            )
        }

        guard maxAbsValue > 0 else {
            return points.map { _ in SCNVector3Zero }
        }

        let scale: Float = 1.8 / maxAbsValue

        return points.map { point in
            SCNVector3(
                point.x * scale,
                point.y * scale,
                point.z * scale
            )
        }
    }

    private static func addTrajectory(points: [SCNVector3], to root: SCNNode) {
        guard points.count >= 2 else { return }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let progress = CGFloat(index) / CGFloat(max(points.count - 1, 1))

            let color = UIColor(
                hue: progress * 0.65,
                saturation: 0.85,
                brightness: 0.95,
                alpha: 1.0
            )

            let lineNode = makeCylinderLine(
                from: start,
                to: end,
                radius: 0.012,
                color: color
            )

            root.addChildNode(lineNode)
        }
    }

    private static func addStartEndMarkers(points: [SCNVector3], to root: SCNNode) {
        guard let first = points.first,
              let last = points.last else {
            return
        }

        let startNode = makeSphere(
            radius: 0.06,
            color: .systemGreen,
            position: first
        )

        let endNode = makeSphere(
            radius: 0.06,
            color: .systemRed,
            position: last
        )

        root.addChildNode(startNode)
        root.addChildNode(endNode)
    }

    private static func addAxes(to root: SCNNode) {
        let axisLength: Float = 2.2

        let xAxis = makeCylinderLine(
            from: SCNVector3(-axisLength, 0, 0),
            to: SCNVector3(axisLength, 0, 0),
            radius: 0.006,
            color: .systemRed.withAlphaComponent(0.55)
        )

        let yAxis = makeCylinderLine(
            from: SCNVector3(0, -axisLength, 0),
            to: SCNVector3(0, axisLength, 0),
            radius: 0.006,
            color: .systemGreen.withAlphaComponent(0.55)
        )

        let zAxis = makeCylinderLine(
            from: SCNVector3(0, 0, -axisLength),
            to: SCNVector3(0, 0, axisLength),
            radius: 0.006,
            color: .systemBlue.withAlphaComponent(0.55)
        )

        root.addChildNode(xAxis)
        root.addChildNode(yAxis)
        root.addChildNode(zAxis)

        addAxisLabel("X", position: SCNVector3(axisLength + 0.18, 0, 0), color: .systemRed, to: root)
        addAxisLabel("Y", position: SCNVector3(0, axisLength + 0.18, 0), color: .systemGreen, to: root)
        addAxisLabel("Z", position: SCNVector3(0, 0, axisLength + 0.18), color: .systemBlue, to: root)
    }

    private static func addAxisLabel(
        _ text: String,
        position: SCNVector3,
        color: UIColor,
        to root: SCNNode
    ) {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.01)
        textGeometry.font = .systemFont(ofSize: 0.24, weight: .bold)
        textGeometry.firstMaterial?.diffuse.contents = color
        textGeometry.flatness = 0.2

        let node = SCNNode(geometry: textGeometry)
        node.position = position
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        node.constraints = [SCNBillboardConstraint()]
        root.addChildNode(node)
    }

    private static func addTitle(_ title: String, to root: SCNNode) {
        let textGeometry = SCNText(string: title, extrusionDepth: 0.01)
        textGeometry.font = .systemFont(ofSize: 0.18, weight: .semibold)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.secondaryLabel
        textGeometry.flatness = 0.2

        let node = SCNNode(geometry: textGeometry)
        node.position = SCNVector3(-1.3, 2.45, 0)
        node.scale = SCNVector3(0.45, 0.45, 0.45)
        node.constraints = [SCNBillboardConstraint()]
        root.addChildNode(node)
    }

    private static func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 55
        cameraNode.position = SCNVector3(0, 0, 5.4)
        scene.rootNode.addChildNode(cameraNode)
    }

    private static func addLight(to scene: SCNScene) {
        let omniLight = SCNLight()
        omniLight.type = .omni
        omniLight.intensity = 700

        let omniNode = SCNNode()
        omniNode.light = omniLight
        omniNode.position = SCNVector3(2, 3, 4)
        scene.rootNode.addChildNode(omniNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 350

        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
    }

    private static func makeSphere(
        radius: CGFloat,
        color: UIColor,
        position: SCNVector3
    ) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.firstMaterial?.diffuse.contents = color

        let node = SCNNode(geometry: sphere)
        node.position = position

        return node
    }

    private static func makeCylinderLine(
        from start: SCNVector3,
        to end: SCNVector3,
        radius: CGFloat,
        color: UIColor
    ) -> SCNNode {
        let vector = SCNVector3(
            end.x - start.x,
            end.y - start.y,
            end.z - start.z
        )

        let height = CGFloat(
            sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        )

        guard height > 0.0001 else {
            return SCNNode()
        }

        let cylinder = SCNCylinder(radius: radius, height: height)
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )

        node.eulerAngles = cylinderEulerAngles(from: vector)

        return node
    }

    private static func cylinderEulerAngles(from vector: SCNVector3) -> SCNVector3 {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)

        guard length > 0.0001 else {
            return SCNVector3Zero
        }

        let normalized = SCNVector3(
            vector.x / length,
            vector.y / length,
            vector.z / length
        )

        let pitch = atan2(normalized.x, normalized.y)
        let roll = atan2(
            normalized.z,
            sqrt(normalized.x * normalized.x + normalized.y * normalized.y)
        )

        return SCNVector3(roll, 0, -pitch)
    }
}
