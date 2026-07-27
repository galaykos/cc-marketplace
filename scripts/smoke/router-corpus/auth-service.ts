export function authenticate(jwt: string) {
  const secret = process.env.API_KEY
  if (!verify(jwt, secret)) throw new Error('bad token')
  return decode(jwt)
}
