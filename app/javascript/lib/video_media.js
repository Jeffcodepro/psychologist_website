export function youtubeId(value) {
  try {
    const url = new URL(value.trim())
    if (!["https:", "http:"].includes(url.protocol) || url.username || url.password || url.port) return null
    let id
    if (["youtu.be", "www.youtu.be"].includes(url.hostname)) id = url.pathname.slice(1)
    else if (["youtube.com", "www.youtube.com", "m.youtube.com", "youtube-nocookie.com", "www.youtube-nocookie.com"].includes(url.hostname)) {
      if (url.pathname === "/watch") id = url.searchParams.get("v")
      else if (/^\/(embed|shorts|live)\//.test(url.pathname)) id = url.pathname.split("/")[2]
    }
    return /^[a-zA-Z0-9_-]{11}$/.test(id || "") ? id : null
  } catch { return null }
}

export function videoPreview({youtube, url, title = "Vídeo"}) {
  const box = document.createElement("div")
  box.className = "cms-video"
  Object.assign(box.dataset, { controller: "video-player", videoPlayerYoutubeValue: youtube || "", videoPlayerUrlValue: url || "", videoPlayerTitleValue: title })
  const poster = document.createElement(youtube ? "img" : "video")
  poster.className = "cms-video__poster"
  if (youtube) { poster.src = `https://i.ytimg.com/vi/${youtube}/hqdefault.jpg`; poster.alt = "" }
  else { poster.src = url; poster.muted = true; poster.playsInline = true; poster.preload = "metadata" }
  const play = document.createElement("button")
  play.type = "button"
  play.className = "cms-video__play"
  play.dataset.action = "video-player#play"
  play.setAttribute("aria-label", `Reproduzir vídeo: ${title}`)
  const icon = document.createElement("span"); icon.textContent = "▶"; icon.setAttribute("aria-hidden", "true")
  play.append(icon); box.append(poster, play)
  return box
}
