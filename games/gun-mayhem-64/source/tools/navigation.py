"""Compact platform routes for the C64's fixed screen and jump envelope."""
from collections import deque

MAX_RISE = 3
MAX_GAP = 7


def gap(a, b):
    return max(0, b[0]-a[0]-a[2], a[0]-b[0]-b[2])


def edges(platforms):
    return [[j for j, b in enumerate(platforms)
             if i != j and a[1]-b[1] <= MAX_RISE and gap(a, b) <= MAX_GAP]
            for i, a in enumerate(platforms)]


def reachable(graph, start):
    seen = {start}
    queue = deque([start])
    while queue:
        for node in graph[queue.popleft()]:
            if node not in seen:
                seen.add(node)
                queue.append(node)
    return seen


def prepare(platforms):
    # Keep the floor fixed and lower high tiers into the ordinary jump envelope.
    rows = sorted({p[1] for p in platforms}, reverse=True)
    lowered = {rows[0]: rows[0]}
    for upper, lower in zip(rows[1:], rows):
        lowered[upper] = max(upper, lowered[lower]-MAX_RISE)
    result = [[x, lowered[y], width] for x, y, width in platforms]
    floor = max(range(len(result)), key=lambda i: result[i][1])
    # An offset tower can still miss a tier that exists only across the arena.
    for _ in result:
        seen = reachable(edges(result), floor)
        if len(seen) == len(result):
            break
        options = [(max(0, result[s][1]-MAX_RISE-result[t][1]), gap(result[s], result[t]), s, t)
                   for s in seen for t in range(len(result)) if t not in seen
                   and result[s][1] > result[t][1] and gap(result[s], result[t]) <= MAX_GAP]
        if not options:
            raise ValueError('Arena needs a horizontal stepping platform')
        _, _, source, target = min(options)
        result[target][1] = result[source][1]-MAX_RISE
    graph = edges(result)
    routes = bytearray()
    for start in range(len(result)):
        first = {start: start}
        queue = deque([start])
        while queue:
            current = queue.popleft()
            # Prefer overlapping platforms when equally short routes exist.
            for target in sorted(graph[current], key=lambda j: (gap(result[current], result[j]), j)):
                if target not in first:
                    first[target] = target if current == start else first[current]
                    queue.append(target)
        if len(first) != len(result):
            raise ValueError(f'Platform {start} cannot reach the entire arena')
        routes.extend(first[target] for target in range(len(result)))
    return result, routes
