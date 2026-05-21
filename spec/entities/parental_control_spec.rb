# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entities::ParentalControl do
  let(:user) { AppUser.create!(uuid: SecureRandom.uuid, phone: '13800138000') }
  let(:parental) { ParentalControl.create!(app_user: user, password: '1234', time_limit_minutes: 30, phone: '13900139000', is_active: true) }

  subject(:json) { described_class.represent(parental).as_json }

  it 'exposes time_limit_minutes' do
    expect(json[:time_limit_minutes]).to eq(30)
  end

  it 'exposes time_limit_label' do
    expect(json[:time_limit_label]).to eq('30分钟')
  end

  it 'exposes time_limit_label as 无限制 when nil' do
    parental.update!(time_limit_minutes: nil)
    json = described_class.represent(parental).as_json
    expect(json[:time_limit_label]).to eq('无限制')
  end

  it 'exposes phone' do
    expect(json[:phone]).to eq('13900139000')
  end

  it 'exposes phone_masked' do
    expect(json[:phone_masked]).to eq('139****9000')
  end

  it 'exposes phone_masked as empty when phone is blank' do
    parental.update!(phone: nil)
    json = described_class.represent(parental).as_json
    expect(json[:phone_masked]).to eq('')
  end

  it 'exposes blacklist_count' do
    expect(json[:blacklist_count]).to eq(0)
  end

  it 'exposes is_active' do
    expect(json[:is_active]).to be true
  end
end
