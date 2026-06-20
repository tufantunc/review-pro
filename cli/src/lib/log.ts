export function info(msg: string): void {
  console.log(msg);
}
export function warn(msg: string): void {
  console.error(`warn: ${msg}`);
}
export function fail(msg: string): void {
  console.error(`error: ${msg}`);
}
