import h from 'vhtml'
/** @jsx h */

export const SearchHelp = ({ children, ...props }) => (
  <div>
    You can search by a partial name, an email address, a partial tag, or a user ID:
    <ul className="usersearch--helplist">
      <li>To search by partial name, enter at least one word of the name.</li>
      <li>To search by email address, enter the full email address.</li>
      <li>To search by partial tag, enter a <code>!</code> character, followed by part of the tag.</li>
      <li>To search by user ID, enter a <code>#</code> character, followed by the user ID.</li>
    </ul>
    You can specify multiple search terms to filter the results, for example:
    <ul className="usersearch--helplist">
      <li>To see all advocacy volunteers: <code>!advo !vol</code></li>
      <li>To see users with "test" in their name who are also NRER volunteers: <code>test !nrer</code></li>
    </ul>
  </div>
)

export const UserItem = ({ children, user, ...props }) => (
  <li id={`usersearch--uid${user.uid}`} className="usersearch--user" data-uid={user.uid} data-name={user.name} {...props}>
    <i className="fa fa-user" />&nbsp;
    <span className="usersearch--user--name">{user.name}</span>
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
    onlyAssignable: parseInt(searchField.getAttribute('data-only-assignable')) > 0,
    onlyCaseAssigned: parseInt(searchField.getAttribute('data-only-case-assigned')),
  }

  window.kukupa.user_search[fieldId].searchAgainOnClickHandler = (e) => {
    e.preventDefault()

    let selectedElement = document.getElementById(`usersearch--selected${fieldId}`)
    if (typeof selectedElement !== "undefined") {
      selectedElement.innerHTML = (
        <SearchHelp />
      )
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
          <span
            className="usersearch--selecteduser--again usersearch-smolbutton"
            onclick={`window.kukupa.user_search['${fieldId}'].searchAgainOnClickHandler(event)`}
          >
            <i className="fa fa-search" />&nbsp;
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
      let formData = new FormData()
      formData.append('query', value)
      if (window.kukupa.user_search[fieldId].onlyAssignable) {
        formData.append('only_assignable', '1')
      }
      if (window.kukupa.user_search[fieldId].onlyCaseAssigned > 0) {
        formData.append('only_case_assigned', window.kukupa.user_search[fieldId].onlyCaseAssigned)
      }

      fetch('/api/user-search', {
        method: 'POST',
        body: formData,
      })
      .then(response => response.json())
      .then(result => {
        if (typeof result.users === "undefined" || result.users.length == 0) {
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
      <div id={`usersearch--selected${fieldId}`} className="usersearch--selecteduser inline-form">
        <SearchHelp />
      </div>
      <input
        id={`usersearch--search${fieldId}`} className="usersearch--search" type="search"
        placeholder="Start typing to search…"
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
