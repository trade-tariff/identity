import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import { SourceTextModule } from 'node:vm'

const assets = new URL('../../public/assets/', import.meta.url)
const manifest = JSON.parse(readFileSync(new URL('.manifest.json', assets), 'utf8'))

function packagedModule (name) {
  assert.ok(manifest[name], `${name} must be precompiled`)
  return new SourceTextModule(readFileSync(new URL(manifest[name].digested_path, assets), 'utf8'))
}

test('the packaged GOV.UK distribution has no missing module dependencies', async () => {
  const govuk = packagedModule('govuk-frontend.js')
  assert.deepEqual(govuk.dependencySpecifiers, [], 'Vendor the complete GOV.UK bundle, not all.mjs')
  await govuk.link(() => { throw new Error('Unexpected dependency') })
  assert.equal(govuk.status, 'linked')
})

test('the application links to its packaged dependencies', async () => {
  const application = packagedModule('application.js')
  await application.link(specifier => {
    assert.ok(['govuk-frontend', 'otp_input'].includes(specifier), `Unexpected dependency: ${specifier}`)
    return packagedModule(`${specifier}.js`)
  })
  assert.equal(application.status, 'linked')
})
