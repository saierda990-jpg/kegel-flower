import Foundation

@main
struct PopoverSnoozeBehaviorTests {
    static func main() {
        assert(PopoverSnoozeBehavior.shouldReschedule(for: .idle) == false)
        assert(PopoverSnoozeBehavior.shouldReschedule(for: .reminding) == true)

        print("PopoverSnoozeBehaviorTests passed")
    }
}
