export function initOtpInput (input) {
  if (input.dataset.otpEnhanced) return

  const group = document.createElement('div')
  group.className = 'otp-input'
  group.setAttribute('role', 'group')
  group.setAttribute('aria-label', '6-digit code')

  const boxes = Array.from({ length: 6 }, (_, index) => {
    const box = document.createElement('input')
    box.type = 'text'
    box.id = index === 0 ? input.id : `${input.id}-${index + 1}`
    box.className = 'govuk-input otp-input__box'
    box.classList.toggle('govuk-input--error', input.classList.contains('govuk-input--error'))
    box.inputMode = 'numeric'
    // Allow a complete code from mobile autofill as well as clipboard paste.
    box.maxLength = 6
    box.autocomplete = index === 0 ? 'one-time-code' : 'off'
    box.setAttribute('aria-label', `Digit ${index + 1} of 6`)
    if (input.hasAttribute('aria-describedby')) {
      box.setAttribute('aria-describedby', input.getAttribute('aria-describedby'))
    }
    group.appendChild(box)
    return box
  })

  const sync = () => { input.value = boxes.map(box => box.value).join('') }
  const insert = (text, index) => {
    const digits = text.replace(/\D/g, '').slice(0, boxes.length)
    if (!digits) return
    const start = digits.length === boxes.length ? 0 : index
    digits.split('').forEach((digit, offset) => {
      if (boxes[start + offset]) boxes[start + offset].value = digit
    })
    sync()
    boxes[Math.min(start + digits.length, boxes.length - 1)].focus()
  }

  boxes.forEach((box, index) => {
    box.addEventListener('focus', () => box.select())
    box.addEventListener('input', event => {
      const value = event.inputType === 'insertText' && event.data?.length === 1 ? event.data : box.value
      box.value = ''
      insert(value, index)
      sync()
    })
    box.addEventListener('paste', event => {
      event.preventDefault()
      insert(event.clipboardData.getData('text'), index)
    })
    box.addEventListener('keydown', event => {
      if (event.key === 'Backspace') {
        event.preventDefault()
        if (box.value) {
          box.value = ''
        } else if (index > 0) {
          boxes[index - 1].value = ''
          boxes[index - 1].focus()
        }
        sync()
      } else if (event.key === 'ArrowLeft' && index > 0) {
        event.preventDefault()
        boxes[index - 1].focus()
      } else if (event.key === 'ArrowRight' && index < boxes.length - 1) {
        event.preventDefault()
        boxes[index + 1].focus()
      } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !/^\d$/.test(event.key)) {
        event.preventDefault()
      }
    })
  })

  // Keep the real named input visible and usable until enhancement is complete.
  input.value.replace(/\D/g, '').slice(0, 6).split('').forEach((digit, index) => {
    boxes[index].value = digit
  })
  input.form.addEventListener('submit', sync, { capture: true })
  input.removeAttribute('id')
  input.type = 'hidden'
  input.dataset.otpEnhanced = 'true'
  input.after(group)
}

function init () {
  document.querySelectorAll('input[data-otp-input]').forEach(initOtpInput)
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
