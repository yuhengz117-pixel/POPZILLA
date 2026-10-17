import SwiftUI

/// Toy-scale Godzilla over an isometric city diorama. One asset, independently animated city geometry.
struct KaijuScene: View {
    let xp: Int
    var event: KaijuEvent? = nil
    var compact = false
    var evolutions = 0
    var buildings = 0
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.scenePhase) private var scenePhase
    private var heat: Color { xp >= 700 ? .orange : Color(red: 0.18, green: 0.78, blue: 1) }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: compact || reducedMotion || scenePhase != .active)) { clock in
            let elapsed = event.map { clock.date.timeIntervalSince($0.date) } ?? 99
            let active = !compact && elapsed >= 0 && elapsed < 4.2
            Canvas { context, size in
                context.scaleBy(x: size.width / 400, y: size.height / 260)
                drawStage(&context, time: clock.date.timeIntervalSinceReferenceDate,
                          elapsed: reducedMotion ? 4.1 : elapsed, active: active)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(active ? (event?.kind == .evolution ? "觉醒啦！背鳍充能" : elapsed < 1.4 ? "这一脚，拆了！" : "原子吐息 / 清理现场") : "MINI TOKYO · 巨兽游乐场")
                        .font(.system(size: compact ? 8 : 10, weight: .bold, design: .monospaced)).tracking(1)
                    if active { Text("+\(event?.xp ?? 20) XP").font(.title3.bold()).foregroundStyle(heat) }
                }.padding(compact ? 8 : 14)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Q版哥斯拉，\(xp)经验，俯视立体城市。已踏平\(buildings)栋楼。")
    }
    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        if let first = points.first { path.move(to: first) }
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath(); return path
    }
    private func face(_ context: inout GraphicsContext, _ points: [CGPoint], _ color: Color) {
        let path = polygon(points)
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(.black.opacity(0.2)), lineWidth: 0.7)
    }
    private func tower(_ context: inout GraphicsContext, index: Int, collapse: Double) {
        let x = CGFloat(166 + index * 34), y = CGFloat(216 - index * 12)
        let w: CGFloat = 24, d: CGFloat = 14
        let full = CGFloat([50, 68, 43, 59, 78, 48][index])
        let h = full * (1 - collapse * 0.95)
        var tower = context
        // Each chunk tips slightly as the tower is compressed into rubble.
        tower.translateBy(x: x + collapse * 3, y: y)
        face(&tower, [.init(x: 0,y: 0), .init(x: w,y: 8), .init(x: w,y: 8-h), .init(x: 0,y: -h)], Color(red: 0.29, green: 0.4, blue: 0.48))
        face(&tower, [.init(x: w,y: 8), .init(x: w+d,y: -3), .init(x: w+d,y: -3-h), .init(x: w,y: 8-h)], Color(red: 0.15, green: 0.23, blue: 0.31))
        face(&tower, [.init(x: 0,y: -h), .init(x: w,y: 8-h), .init(x: w+d,y: -3-h), .init(x: d,y: -11-h)], Color(red: 0.48, green: 0.6, blue: 0.66))
        if collapse < 0.7 {
            for row in 0..<Int(full / 11) { for col in 0..<3 {
                let wx = CGFloat(4 + col * 7), wy = -h + CGFloat(7 + row * 10) + wx / 3
                let color = (row + col + index) % 3 == 0 ? Color(red: 1,green: 0.79,blue: 0.34) : heat.opacity(0.65)
                tower.fill(polygon([.init(x: wx,y: wy), .init(x: wx+3,y: wy+1), .init(x: wx+3,y: wy+5), .init(x: wx,y: wy+4)]), with: .color(color))
            } }
            face(&tower, [.init(x: 8,y: -h-1), .init(x: 14,y: -h+1), .init(x: 20,y: -h-4), .init(x: 14,y: -h-6)], Color(white: 0.35))
        } else {
            for i in 0..<8 {
                let dx = CGFloat((i * 11) % 40), dy = CGFloat((i * 7) % 13 - 4)
                let jump = sin(collapse * .pi) * Double(18 + i * 4)
                face(&tower, [.init(x: dx,y: dy-jump), .init(x: dx+6,y: dy+3-jump), .init(x: dx+9,y: dy-jump), .init(x: dx+3,y: dy-3-jump)], Color(white: 0.4 + Double(i % 3) * 0.1))
            }
        }
    }
    private func drawStage(_ context: inout GraphicsContext, time: Double, elapsed t: Double, active: Bool) {
        context.fill(Path(CGRect(x: 0,y: 0,width: 400,height: 260)), with: .linearGradient(Gradient(colors: [Color(red: 0.045,green: 0.08,blue: 0.11), Color(red: 0.09,green: 0.14,blue: 0.18)]), startPoint: .zero, endPoint: .init(x: 400,y: 260)))
        let rampage = active && event?.kind == .rampage
        let evolution = active && event?.kind == .evolution
        let collapse = rampage ? min(1, max(0, (t - 0.65) / 0.65)) : 0
        let target = max(0, buildings - 1) % 6
        let ruined = buildings == 0 ? 0 : (buildings - 1) % 6 + 1
        let shake = rampage && t > 0.6 && t < 1.4 && !reducedMotion ? sin(t * 65) * (1-collapse) * 3 : 0
        context.translateBy(x: shake,y: 0)
        // Elevated tabletop city: diamond ground plane, visible slab thickness, parallel streets.
        context.fill(Path(ellipseIn: CGRect(x: 35,y: 210,width: 335,height: 39)), with: .color(.black.opacity(0.3)))
        face(&context, [.init(x: 25,y: 160), .init(x: 202,y: 242), .init(x: 202,y: 252), .init(x: 25,y: 170)], Color(red: 0.08,green: 0.14,blue: 0.19))
        face(&context, [.init(x: 202,y: 242), .init(x: 389,y: 164), .init(x: 389,y: 174), .init(x: 202,y: 252)], Color(red: 0.045,green: 0.085,blue: 0.12))
        face(&context, [.init(x: 25,y: 160), .init(x: 217,y: 86), .init(x: 389,y: 164), .init(x: 202,y: 242)], Color(red: 0.19,green: 0.28,blue: 0.31))
        face(&context, [.init(x: 88,y: 188), .init(x: 280,y: 113), .init(x: 298,y: 121), .init(x: 105,y: 196)], Color(white: 0.13))
        face(&context, [.init(x: 142,y: 211), .init(x: 334,y: 137), .init(x: 349,y: 144), .init(x: 157,y: 218)], Color(white: 0.13))
        for i in 0..<11 {
            let x = CGFloat(156 + i * 16), y = CGFloat(209 - i * 6)
            context.stroke(polygon([.init(x: x,y: y), .init(x: x+6,y: y-2), .init(x: x+7,y: y-1), .init(x: x+1,y: y+1)]), with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
        // The six towers are a single row; farther towers draw first for correct isometric depth.
        for i in (0..<6).reversed() {
            let amount = rampage && i == target ? collapse : (i < ruined ? 1.0 : 0.0)
            tower(&context, index: i, collapse: amount)
        }
        let growth = 0.71 + min(0.24, Double(xp) / 2200) + (evolutions > 0 ? 0.025 : 0)
        let charge = evolution ? sin(min(1,t / 3.7) * .pi) : 0
        let move = rampage ? min(1,t / 0.65) : 0
        let targetX = CGFloat(184 + target * 34), targetY = CGFloat(218 - target * 12)
        let actorX = 111 + (targetX - 111 - 55 * growth) * move
        let actorY = 186 + (targetY - 186 - 6 * growth) * move
        let lift = rampage && t < 0.65 && !reducedMotion ? sin(t / 0.65 * .pi) * 22 : 0
        let breathe = compact || reducedMotion ? 0 : sin(time * 1.8) * 0.004
        let scale = growth + breathe + charge * 0.045
        context.fill(Path(ellipseIn: CGRect(x: actorX-42,y: actorY-10,width: 91,height: 26)), with: .color(.black.opacity(0.32)))
        var beast = context
        beast.translateBy(x: actorX,y: actorY-lift)
        beast.scaleBy(x: scale,y: scale)
        if xp >= 700 { beast.addFilter(.hueRotation(.degrees(155))) }
        if evolution || evolutions > 0 {
            var halo = beast; halo.addFilter(.blur(radius: 13))
            halo.fill(Path(ellipseIn: CGRect(x: -62,y: -175,width: 140,height: 177)), with: .color(heat.opacity(0.15 + charge * 0.3)))
        }
        // Silver dorsal plates in idle form, cyan energy drawn only during charge/breath/evolution.
        beast.draw(Image("Godzilla"), in: CGRect(x: -115,y: -198,width: 210,height: 210))
        let breath = rampage && t > 1.4 && t < 3.7
        if breath || evolution || evolutions > 0 {
            var energy = beast; energy.addFilter(.blur(radius: 4))
            energy.opacity = evolution ? charge * 0.8 : breath ? 0.7 : 0.24
            for i in 0..<5 {
                energy.fill(Path(ellipseIn: CGRect(x: -53+Double(i)*12,y: -91-Double(i)*21,width: 13,height: 15)), with: .color(heat))
            }
        }
        if rampage && t > 0.6 && t < 1.5 && !reducedMotion {
            let radius = (t-0.6) * 55
            context.stroke(Path(ellipseIn: CGRect(x: targetX-radius,y: targetY-radius*0.3,width: radius*2,height: radius*0.6)), with: .color(heat.opacity(max(0,1-(t-0.6)))), lineWidth: 2)
            var dust = context; dust.addFilter(.blur(radius: 4))
            dust.fill(Path(ellipseIn: CGRect(x: targetX-23,y: targetY-25,width: 75,height: 28)), with: .color(Color(white: 0.7).opacity(sin(collapse * .pi)*0.4)))
        }
        if breath {
            let mouth = CGPoint(x: actorX + 55*scale,y: actorY - 93*scale)
            let end = CGPoint(x: targetX+12,y: targetY-4)
            let progress = min(1,(t-1.4)/0.18)
            let tip = CGPoint(x: mouth.x+(end.x-mouth.x)*progress,y: mouth.y+(end.y-mouth.y)*progress)
            let ray = polygon([mouth,.init(x: tip.x-12,y: tip.y-3),.init(x: tip.x+12,y: tip.y+5)])
            var glow = context; glow.addFilter(.blur(radius: 7)); glow.fill(ray, with: .color(heat.opacity(0.85)))
            context.fill(ray, with: .linearGradient(Gradient(colors: [.white,heat]), startPoint: mouth,endPoint: tip))
            for i in 0..<12 {
                let pulse = reducedMotion ? 0.5 : sin(time*13+Double(i))
                let h = 12+Double(i%4)*6+pulse*4
                let rect = CGRect(x: targetX-12+Double(i*5%49),y: targetY-h,width: 10,height: h)
                context.fill(Path(ellipseIn: rect), with: .color((i%3==0 ? Color.yellow : .orange).opacity(0.85)))
            }
        }
        if evolution && !reducedMotion {
            let radius = 24+min(1,t/3.7)*93
            context.stroke(Path(ellipseIn: CGRect(x: actorX-radius,y: actorY-65-radius,width: radius*2,height: radius*2)), with: .color(heat.opacity(max(0,0.75-t/6))), lineWidth: 1.4)
        }
    }
}
