# Code Samples

Fenced code blocks that name their language are coloured in the rendered pane.

```swift
import SwiftUI

/// Shows how many days are left on a habit streak.
struct StreakView: View {
    let streak: Int
    var goal = 30

    var body: some View {
        Text("\(goal - streak) days to go")
            .font(.headline)
    }
}
```

```python
from datetime import date

def days_until(target: date) -> int:
    """Return the number of days until the target date."""
    return (target - date.today()).days  # may be negative

print(days_until(date(2026, 4, 14)), True)
```

```json
{ "name": "Lumen", "version": "1.0", "trialDays": 14, "beta": false }
```
