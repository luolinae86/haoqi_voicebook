# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entities::AppUser do
  let(:grade) { Grade.create!(name: '一年级') }
  let(:user) { AppUser.create!(grade_id: grade.id, uuid: SecureRandom.uuid, phone: '13800138000') }
  let(:user_without_grade) { AppUser.create!(uuid: SecureRandom.uuid, phone: '13800138001') }

  subject(:json) { described_class.represent(user).as_json }

  it 'exposes grade_name instead of grade_id' do
    expect(json).to include(:grade_name)
    expect(json[:grade_name]).to eq('一年级')
  end

  it 'returns nil grade_name when user has no grade_id' do
    json_without_grade = described_class.represent(user_without_grade).as_json
    expect(json_without_grade[:grade_name]).to be_nil
  end

  it 'returns nil grade_name when grade_id references a non-existent grade' do
    user.update!(grade_id: 999_999)
    json_bad = described_class.represent(user).as_json
    expect(json_bad[:grade_name]).to be_nil
  end
end
