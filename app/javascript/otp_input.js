const DIGIT = /^\d$/

function initOtpInput (container) {
  const boxes = Array.from(container.querySelectorAll('[data-otp-box]'))
  const sink = container.querySelector('[data-otp-value]')

  boxes.forEach((box, idx) => {
    box.addEventListener('focus', () => box.select())

    box.addEventListener('keydown', e => {
      if (e.key === 'Backspace') {
        e.preventDefault()
        if (box.value !== '') {
          box.value = ''
        } else if (idx > 0) {
          boxes[idx - 1].value = ''
          boxes[idx - 1].focus()
        }
      } else if (e.key === 'ArrowLeft' && idx > 0) {
        e.preventDefault()
        boxes[idx - 1].focus()
      } else if (e.key === 'ArrowRight' && idx < boxes.length - 1) {
        e.preventDefault()
        boxes[idx + 1].focus()
      } else if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !DIGIT.test(e.key)) {
        e.preventDefault()
      }
    })

    box.addEventListener('input', () => {
      if (box.value && idx < boxes.length - 1) {
        boxes[idx + 1].focus()
        boxes[idx + 1].select()
      }
    })

    box.addEventListener('paste', e => {
      e.preventDefault()
      const digits = (e.clipboardData || window.clipboardData)
        .getData('text')
        .replace(/\D/g, '')
        .slice(0, boxes.length)
      digits.split('').forEach((d, j) => { if (boxes[j]) boxes[j].value = d })
      boxes[Math.min(digits.length, boxes.length - 1)].focus()
    })
  })

  container.closest('form').addEventListener('submit', () => {
    sink.value = boxes.map(b => b.value).join('')
  }, { capture: true })
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-otp-input]').forEach(initOtpInput)
})
