// Total acceleration in g, whatever the orientation of the watch.
export function magnitude({ x, y, z }) {
  return Math.hypot(x, y, z);
}
