import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import { SourceTextModule } from 'node:vm'
import { JSDOM } from 'jsdom'

const assets = new URL('../../public/assets/', import.meta.url)
const manifest = JSON.parse(readFileSync(new URL('.manifest.json', assets), 'utf8'))

function packagedModule (name, context) {
  assert.ok(manifest[name], `${name} must be precompiled`)
  return new SourceTextModule(readFileSync(new URL(manifest[name].digested_path, assets), 'utf8'), { context })
}

test('the packaged GOV.UK distribution has no missing module dependencies', async () => {
  const govuk = packagedModule('govuk-frontend.js')
  assert.deepEqual(govuk.dependencySpecifiers, [], 'Vendor the complete GOV.UK bundle, not all.mjs')
  await govuk.link(() => { throw new Error('Unexpected dependency') })
  assert.equal(govuk.status, 'linked')
})

test('the packaged application initialises GOV.UK and the six code boxes', async t => {
  const dom = new JSDOM(`
    <body class="govuk-frontend-supported">
      <form>
        <label for="code">6-digit code</label>
        <input id="code" name="passwordless_code_form[code]" data-otp-input>
        <button data-module="govuk-button">Continue</button>
      </form>
    </body>`, { runScripts: 'outside-only' })
  t.after(() => dom.window.close())
  const context = dom.getInternalVMContext()
  const application = packagedModule('application.js', context)
  await application.link(specifier => {
    assert.ok(['govuk-frontend', 'otp_input'].includes(specifier), `Unexpected dependency: ${specifier}`)
    return packagedModule(`${specifier}.js`, context)
  })
  await application.evaluate()
  dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'))
  assert.ok(dom.window.document.querySelector('[data-govuk-button-init]'))
  assert.equal(dom.window.document.querySelectorAll('.otp-input__box').length, 6)
})
