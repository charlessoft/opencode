import { ComponentProps } from "solid-js"

export const Mark = (props: { class?: string }) => {
  return (
    <img
      data-component="logo-mark"
      src="/home-logo.png"
      alt=""
      classList={{ [props.class ?? ""]: !!props.class }}
      draggable={false}
    />
  )
}

export const Splash = (props: Pick<ComponentProps<"img">, "ref" | "class">) => {
  return (
    <img
      ref={props.ref}
      data-component="logo-splash"
      src="/home-logo.png"
      alt=""
      classList={{ [props.class ?? ""]: !!props.class }}
      draggable={false}
    />
  )
}

export const Logo = (props: { class?: string }) => {
  return (
    <img
      src="/home-logo.png"
      alt=""
      classList={{ [props.class ?? ""]: !!props.class }}
      draggable={false}
    />
  )
}
