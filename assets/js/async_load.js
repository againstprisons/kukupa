export const asyncLoad = (paths) => {
  let firstScript = document.getElementsByTagName('script')[0]
  Array.from(paths).forEach((p) => {
    let s = document.createElement('script')
    s.src = p
    s.type = 'text/javascript'
    s.async = true
    firstScript.parentNode.insertBefore(s, firstScript)
  })
}

export const asyncLoadFromElements = () => {
  let paths = []
  let asyncElements = document.querySelectorAll('.async-load')
  Array.from(asyncElements).forEach((s) => {
    Array.from(JSON.parse(s.getAttribute('data-sources'))).forEach((p) => {
      paths.push(p)
    })
  })

  if (paths.length > 0) {
    asyncLoad(paths)
  }
}

asyncLoadFromElements()
