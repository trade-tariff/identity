import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import { SourceTextModule } from 'node:vm'
import { JSDOM } from 'jsdom'

const source = readFileSync(new URL('../../app/javascript/otp_input.js', import.meta.url), 'utf8')

async function form (t, value = '') {
  const dom = new JSDOM(`
    <form>
      <label for="code">6-digit code</label>
      <p id="code-error">Enter the 6-digit code from your email</p>
      <input id="code" name="passwordless_code_form[code]" data-otp-input
             class="govuk-input govuk-input--error" aria-describedby="code-error">
    </form>`, { runScripts: 'outside-only' })
  t.after(() => dom.window.close())
  const { document } = dom.window
  const input = document.querySelector('input')
  input.setAttribute('value', value)
  const module = new SourceTextModule(source, { context: dom.getInternalVMContext() })
  await module.link(() => { throw new Error('Unexpected dependency') })
  await module.evaluate()
  document.dispatchEvent(new dom.window.Event('DOMContentLoaded'))
  const boxes = [...document.querySelectorAll('.otp-input__box')]
  const type = (index, text) => {
    boxes[index].focus()
    boxes[index].value = text
    boxes[index].dispatchEvent(new dom.window.InputEvent('input', { data: text, inputType: 'insertText', bubbles: true }))
  }
  const paste = (index, text) => {
    const event = new dom.window.Event('paste', { bubbles: true, cancelable: true })
    Object.defineProperty(event, 'clipboardData', { value: { getData: () => text } })
    boxes[index].dispatchEvent(event)
    assert.equal(event.defaultPrevented, true)
  }
  const code = () => new dom.window.FormData(document.querySelector('form')).get('passwordless_code_form[code]')
  return { dom, document, input, boxes, type, paste, code, module }
}

test('enhances a working named input into six labelled boxes only once', async t => {
  const { document, input, boxes, module } = await form(t)
  module.namespace.initOtpInput(input)
  assert.equal(input.type, 'hidden')
  assert.equal(document.querySelectorAll('.otp-input__box').length, 6)
  assert.equal(document.querySelector('label').control, boxes[0])
  assert.equal(document.getElementById('code'), boxes[0])
  boxes.forEach((box, index) => {
    assert.equal(box.name, '')
    assert.equal(box.getAttribute('aria-label'), `Digit ${index + 1} of 6`)
    assert.equal(box.getAttribute('aria-describedby'), 'code-error')
    assert.equal(box.classList.contains('govuk-input--error'), true)
  })
})

test('typing advances focus and submits all digits, including a leading zero', async t => {
  const { boxes, document, type, code } = await form(t)
  '012345'.split('').forEach((digit, index) => {
    type(index, digit)
    assert.equal(document.activeElement, boxes[Math.min(index + 1, 5)])
  })
  assert.equal(code(), '012345')
})

test('typing at the end of a populated box replaces only that digit', async t => {
  const { dom, document, boxes, code } = await form(t, '012345')
  const box = boxes[3]
  box.focus()
  box.setSelectionRange(1, 1)
  box.setRangeText('9', box.selectionStart, box.selectionEnd, 'end')
  box.dispatchEvent(new dom.window.InputEvent('input', { data: '9', inputType: 'insertText', bubbles: true }))
  assert.deepEqual(boxes.map(box => box.value), ['0', '1', '2', '9', '4', '5'])
  assert.equal(code(), '012945')
  assert.equal(document.activeElement, boxes[4])
})

test('pasting a complete code into any box replaces all six boxes', async t => {
  const { boxes, document, paste, code } = await form(t, '999999')
  paste(3, '012345')
  assert.deepEqual(boxes.map(box => box.value), ['0', '1', '2', '3', '4', '5'])
  assert.equal(code(), '012345')
  assert.equal(document.activeElement, boxes[5])
})

test('pasting tolerates spaces copied with the email code', async t => {
  const { paste, code } = await form(t)
  paste(0, ' 012 345\n')
  assert.equal(code(), '012345')
})

test('mobile autofill distributes the complete code', async t => {
  const { type, code, boxes } = await form(t)
  type(0, '012345')
  assert.equal(code(), '012345')
  assert.equal(boxes[5].value, '5')
})

test('backspace, deletion and arrow navigation keep the submitted value in sync', async t => {
  const { dom, document, boxes, code, type } = await form(t, '012345')
  const key = (index, key) => boxes[index].dispatchEvent(new dom.window.KeyboardEvent('keydown', { key, cancelable: true }))
  key(5, 'Backspace')
  assert.equal(code(), '01234')
  key(5, 'Backspace')
  assert.equal(code(), '0123')
  assert.equal(document.activeElement, boxes[4])
  key(4, 'ArrowLeft')
  assert.equal(document.activeElement, boxes[3])
  key(3, 'ArrowRight')
  assert.equal(document.activeElement, boxes[4])
  type(3, '')
  assert.equal(code(), '012')
})

test('rejects non-digit typing without blocking paste shortcuts', async t => {
  const { dom, boxes, code } = await form(t, '012345')
  const letter = new dom.window.KeyboardEvent('keydown', { key: 'x', cancelable: true })
  boxes[0].dispatchEvent(letter)
  assert.equal(letter.defaultPrevented, true)
  const shortcut = new dom.window.KeyboardEvent('keydown', { key: 'v', ctrlKey: true, cancelable: true })
  boxes[0].dispatchEvent(shortcut)
  assert.equal(shortcut.defaultPrevented, false)
  assert.equal(code(), '012345')
})

test('retains the server-rendered code after a validation error', async t => {
  const { boxes, code } = await form(t, '12')
  assert.deepEqual(boxes.map(box => box.value), ['1', '2', '', '', '', ''])
  assert.equal(code(), '12')
})
