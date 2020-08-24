import ClassicEditor from '@ckeditor/ckeditor5-build-classic'

let editorMaxTries = 10
let editorConfig = {
  removePlugins: ['ImagePlugin'],
  toolbar: [
    'heading',
    '|',
    'bold',
    'italic',
    'link',
    'bulletedList',
    'numberedList',
    'blockQuote',
    '|',
    'undo',
    'redo',
  ],
}

export const enableEditor = (editorElement) => {
  window.kukupa.rich_editors = window.kukupa.rich_editors || {}

  if (typeof(editorElement) !== "object") return
  let editorId = editorElement.id

  // Store some information about the editor surroundings if we haven't done
  // that already
  if (typeof(window.kukupa.rich_editors[editorId]) === "undefined") {
    let p = editorElement.parentElement
    window.kukupa.rich_editors[editorId] = {
      parentElement: p,
      loadingElement: p.querySelector('.editor-message-loading'),
      errorElement: p.querySelector('.editor-message-error'),
      editorTries: 1,
    }
  }

  // If the type of the editor isn't "undefined" then we've loaded successfully
  // in a previous run and we can just bail here
  if (typeof(window.kukupa.rich_editors[editorId].editorObject) !== "undefined") return

  // Log trying
  console.log("Trying to load editor on element id", editorId, "try number", window.kukupa.rich_editors[editorId].editorTries)

  // If we don't have the editor class loaded, try again in one second
  ///
  // XXX: This can probably be removed - if we're here at all then we have the
  // editor as webpack bundles the editor with this JS file
  if (typeof(ClassicEditor) === "undefined") {
    window.kukupa.rich_editors[editorId].editorTries = window.kukupa.rich_editors[editorId].editorTries + 1
    if (window.kukupa.rich_editors[editorId].editorTries > editorMaxTries) {
      console.error("Timed out trying to load editor on element id", editorId)
      window.kukupa.rich_editors[editorId].loadingElement.style.display = 'none'
      window.kukupa.rich_editors[editorId].errorElement.style.display = 'block'
      return
    }

    setTimeout(() => enableEditor(editorElement), 1000)
    return
  }

  // Create the editor!
  console.log("ClassicEditor loaded, creating on element id", editorId)
  ClassicEditor.create(editorElement, editorConfig)
    .then((editor) => {
      window.kukupa.rich_editors[editorId].editorObject = editor

      console.log("Editor created on element id", editorId)
      window.kukupa.rich_editors[editorId].loadingElement.style.display = 'none'
      window.kukupa.rich_editors[editorId].errorElement.style.display = 'none'
    }).catch((e) => {
      console.error("Error while creating editor on element id", editorId, "error", e)

      window.kukupa.rich_editors[editorId].loadingElement.style.display = 'none'
      window.kukupa.rich_editors[editorId].errorElement.style.display = 'block'
    })
}

export const enableAllEditors = () => {
  Array.from(document.querySelectorAll('.rich-editor')).forEach((el) => {
    enableEditor(el)
  })
}

window.kukupa = window.kukupa || {}
enableAllEditors()
