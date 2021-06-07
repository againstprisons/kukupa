import h from 'vhtml'
/** @jsx h */

export const UserItem = ({ children, user, ...props }) => (
  <li id={`usersearch--uid${user.uid}`} className="usersearch--user" data-uid={user.uid} data-name={user.name} {...props}>
    <strong className="usersearch--user--name">{user.name}</strong>
    <ul className="usersearch--user--tags inline-list">
      {user.tags.map(tag => (
        <li className="usersearch--user--tags--tag">
          <span title={tag.tag}>{tag.display}</span>
        </li>
      ))}
    </ul>
    {children.join('')}
  </li>
)

export const enableUserSearch = (searchField) => {
  window.kukupa.user_search = window.kukupa.user_search || {}

  if (typeof searchField !== "object") return
  let fieldId = searchField.id

  if (typeof window.kukupa.user_search[fieldId] !== "undefined") {
    return
  }

  // Create replacement element
  let displayElement = document.createElement('div')
  displayElement.className = 'usersearch'

  // Add replacement element after the actual field
  searchField.parentElement.insertBefore(displayElement, searchField)

  // Hide the original element
  searchField.setAttribute('type', 'hidden')

  window.kukupa.user_search[fieldId] = {
    fieldElement: searchField,
    parentElement: searchField.parentElement,
    displayElement: displayElement,
  }

  window.kukupa.user_search[fieldId].searchAgainOnClickHandler = (e) => {
    e.preventDefault()

    let selectedElement = document.getElementById(`usersearch--selected${fieldId}`)
    if (typeof selectedElement !== "undefined") {
      selectedElement.innerHTML = ''
    }

    let searchElement = document.getElementById(`usersearch--search${fieldId}`)
    if (typeof searchElement !== "undefined") {
      searchElement.classList.remove('usersearch-hidden')
      window.kukupa.user_search[fieldId].doSearch(searchElement.value)
    }

    return false
  }

  window.kukupa.user_search[fieldId].itemOnClickHandler = (e) => {
    e.preventDefault()

    let el = e.target
    if (!el.classList.contains('usersearch--user')) {
      while ((el = el.parentElement) && !el.classList.contains('usersearch--user')) {}
    }

    let uid = el.attributes['data-uid'].value
    searchField.setAttribute('value', uid)

    let selectedElement = document.getElementById(`usersearch--selected${fieldId}`)
    if (typeof selectedElement !== "undefined") {
      selectedElement.innerHTML = (
        <div>
          <strong>Selected user: </strong>
          <span>
            {el.attributes['data-name'].value}
            &nbsp;(ID {el.attributes['data-uid'].value})
          </span>
          <span className="badge x-margin" onclick={`window.kukupa.user_search['${fieldId}'].searchAgainOnClickHandler(event)`}>
            <i className="fa fa-search" />
            Search again
          </span>
        </div>
      )
    }

    let listElement = document.getElementById(`usersearch--list${fieldId}`)
    if (typeof listElement !== "undefined") {
      listElement.innerHTML = ''
    }
    
    let searchElement = document.getElementById(`usersearch--search${fieldId}`)
    if (typeof searchElement !== "undefined") {
      searchElement.classList.add('usersearch-hidden')
    }

    return false
  }

  window.kukupa.user_search[fieldId].doSearch = (value) => {
    let listElement = document.getElementById(`usersearch--list${fieldId}`)
    if (listElement !== "undefined") {
      let formData = new FormData();
      formData.append('query', value)
      fetch('/api/user-search', {
        method: 'POST',
        body: formData,
      })
      .then(response => response.json())
      .then(result => {
        if (result.users.length == 0) {
          listElement.innerHTML = (
            <li className="usersearch--user usersearch--user--invalid">
              <span>No results</span>
            </li>
          )
        } else {
          listElement.innerHTML = result.users.map(user => (
            <UserItem user={user} onclick={`window.kukupa.user_search['${fieldId}'].itemOnClickHandler(event)`} />
          )).join('')
        }
      })
    }
  }

  window.kukupa.user_search[fieldId].onChangeHandler = (e) => {
    e.preventDefault()
    window.kukupa.user_search[fieldId].doSearch(e.target.value)
    return false
  }

  displayElement.innerHTML = (
    <div>
      <div id={`usersearch--selected${fieldId}`} className="usersearch--selecteduser inline-form"/>
      <input
        id={`usersearch--search${fieldId}`} className="usersearch--search" type="search"
        placeholder="Start typing a name to search…"
        onsubmit={`event.preventDefault()`}
        onchange={`window.kukupa.user_search['${fieldId}'].onChangeHandler(event)`} />

      <ul className="usersearch--list" id={`usersearch--list${fieldId}`} />
    </div>
  )
}

export const enableAllUserSearchElements = () => {
  Array.from(document.querySelectorAll('.user-search-field')).forEach((el) => {
    enableUserSearch(el)
  })
}

window.kukupa = window.kukupa || {}
enableAllUserSearchElements()
