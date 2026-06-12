import { Link, Meta } from "@solidjs/meta"

export const Favicon = () => {
  return (
    <>
      <Link rel="icon" type="image/png" href="/home-logo.png?v=1" sizes="30x30" />
      <Link rel="shortcut icon" href="/home-logo.png?v=1" />
      <Link rel="apple-touch-icon" sizes="30x30" href="/home-logo.png?v=1" />
      <Link rel="manifest" href="/site.webmanifest" />
      <Meta name="apple-mobile-web-app-title" content="OpenCode" />
    </>
  )
}
