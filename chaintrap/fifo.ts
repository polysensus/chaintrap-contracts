export function pushFIFO<T>(fifo: T[], capacity: number, ...items: T[]): T[] {
  // easiest case, adding some items, not yet at capacity
  if (fifo.length + items.length < capacity) {
    fifo.push(...items);
    return fifo;
  }

  // easy case. replacing all the elements in one go
  if (items.length >= capacity) {
    fifo.length = 0;
    for (let i = items.length - capacity; i < items.length; i++) {
      fifo.push(items[i]);
    }
    return fifo;
  }

  // items.length is < capacity, fifo.length + items.length is >

  // make room with shift
  const remove = fifo.length + items.length - capacity;
  for (let i = 0; i < remove; i++) fifo.shift();
  fifo.push(...items);

  return fifo;
}
