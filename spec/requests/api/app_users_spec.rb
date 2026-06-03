# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API AppUsers', type: :request do
  let(:user) { create(:app_user) }

  # ==================== 创建设备用户 ====================
  describe 'POST /api/app_users/create_by_device' do
    it '创建新用户并默认三年级' do
      post '/api/app_users/create_by_device',
           params: { device_id: 'test-device-123' },
           as: :json

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:code]).to eq(0)
      user_data = body[:data][:user]
      expect(user_data[:uuid]).to be_present

      created_user = AppUser.find_by(uuid: user_data[:uuid])
      expect(created_user.grade_id).to eq(Grade.find_by(name: '三年级')&.id)
    end

    it '创建新用户时默认昵称为少年越读者' do
      post '/api/app_users/create_by_device',
           params: { device_id: 'test-device-nickname' },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.nickname).to eq('少年越读者')
    end

    it '创建新用户时分配非VIP基础头像' do
      normal_img = create(:head_img, is_vip: false)

      post '/api/app_users/create_by_device',
           params: { device_id: 'test-device-head-img' },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.head_img).to eq(normal_img)
    end

    it '没有可用非VIP头像时创建用户不报错' do
      HeadImg.destroy_all

      post '/api/app_users/create_by_device',
           params: { device_id: 'test-device-no-img' },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.head_img_id).to be_nil
    end

    it 'VIP头像不能作为默认头像' do
      create(:head_img, is_vip: true)

      post '/api/app_users/create_by_device',
           params: { device_id: 'test-device-vip-img' },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.head_img_id).to be_nil
    end

    it '已存在设备时返回已有用户' do
      existing_user = create(:app_user)
      create(:device, device_id: 'existing-device', app_user: existing_user)

      post '/api/app_users/create_by_device',
           params: { device_id: 'existing-device' },
           as: :json

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:data][:user][:uuid]).to eq(existing_user.uuid)
    end
  end

  # ==================== 发送验证码 ====================
  describe 'POST /api/app_users/send_code' do
    before do
      allow_any_instance_of(AliyunSmsService).to receive(:send_verification_code).and_return(true)
    end

    it '发送验证码成功' do
      post '/api/app_users/send_code', params: { uuid: user.uuid, phone: '13800138001' }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
    end

    it '手机号格式不正确返回错误' do
      post '/api/app_users/send_code', params: { uuid: user.uuid, phone: '123' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('手机号格式不正确')
    end
  end

  # ==================== 用户配置 ====================
  describe 'GET /api/app_users/config' do
    it '无家长控制时返回 time_limit_minutes 为 0' do
      get '/api/app_users/config', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:time_limit_minutes]).to eq(0)
    end

    it '有家长控制时返回限制时间' do
      create(:parental_control, app_user: user, time_limit_minutes: 60)

      get '/api/app_users/config', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:time_limit_minutes]).to eq(60)
    end

    it '无效 uuid 返回未授权' do
      get '/api/app_users/config', params: { uuid: 'invalid_uuid_00000' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
    end

    it 'uuid 无效返回未授权错误' do
      post '/api/app_users/send_code', params: { uuid: 'invalid_uuid', phone: '13800138001' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
      expect(json_response[:response][:msg]).to eq('未授权访问')
    end
  end

  # ==================== 获取用户信息 ====================
  describe 'GET /api/app_users/info' do
    it '返回用户基本信息包含 time_limit_minutes' do
      get '/api/app_users/info', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user][:uuid]).to eq(user.uuid)
      expect(json_response[:response][:data][:user][:time_limit_minutes]).to eq(0)
    end

    it '有家长控制时返回正确的 time_limit_minutes' do
      create(:parental_control, app_user: user, time_limit_minutes: 60)

      get '/api/app_users/info', params: { uuid: user.uuid }

      expect(json_response[:response][:data][:user][:time_limit_minutes]).to eq(60)
    end

    it '返回 vip_expires_at 字段且格式正确' do
      user.update!(is_vip: true, vip_expires_at: Time.zone.parse('2026-12-31 23:59:59'))

      get '/api/app_users/info', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:user][:vip_expires_at]).to eq('2026-12-31 23:59:59')
    end

    it 'vip_expires_at 为空时返回 nil' do
      user.update!(vip_expires_at: nil)

      get '/api/app_users/info', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:user][:vip_expires_at]).to be_nil
    end

    it '无效 uuid 返回未授权' do
      get '/api/app_users/info', params: { uuid: 'invalid_uuid' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
    end
  end

  # ==================== 验证码登录 ====================
  describe 'POST /api/app_users/login_by_code' do
    let!(:sms_verification) do
      create(:sms_verification, phone: '13800138000', code: '1234', expires_at: 5.minutes.from_now)
    end

    it '登录成功' do
      post '/api/app_users/login_by_code', params: { uuid: user.uuid, phone: '13800138000', code: '1234' }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user]).to be_present
    end

    it '用户未注册返回错误' do
      post '/api/app_users/login_by_code', params: { uuid: 'invalid_uuid', phone: '13800138000', code: '1234' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('用户未注册，请先调用 create_by_device')
    end

    it '验证码错误返回错误' do
      post '/api/app_users/login_by_code', params: { uuid: user.uuid, phone: '13800138000', code: '9999' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('验证码无效或已过期')
    end

    it '绑定新手机号时直接绑定到当前用户' do
      user.update!(phone: nil)
      create(:sms_verification, phone: '13900139000', code: '5555', expires_at: 5.minutes.from_now)

      post '/api/app_users/login_by_code', params: { uuid: user.uuid, phone: '13900139000', code: '5555' }

      expect(response).to have_http_status(:success)
      expect(user.reload.phone).to eq('13900139000')
      expect(json_response[:response][:data][:user][:uuid]).to eq(user.uuid)
    end

    it '绑定已存在的手机号时，设备转移到主账户，原用户被删除' do
      existing_user = create(:app_user, phone: '13900139001')
      user.update!(phone: nil, wechat_openid: 'oABC123456')
      old_user_id = user.id
      create(:sms_verification, phone: '13900139001', code: '6666', expires_at: 5.minutes.from_now)

      post '/api/app_users/login_by_code', params: { uuid: user.uuid, phone: '13900139001', code: '6666' }

      expect(response).to have_http_status(:success)
      # 返回的是主账户
      expect(json_response[:response][:data][:user][:uuid]).to eq(existing_user.uuid)
      # 原用户被删除
      expect(AppUser.find_by(id: old_user_id)).to be_nil
      # 主账户的 openid 不变
      expect(existing_user.reload.wechat_openid).to be_nil
    end

    it '绑定已存在手机号时，设备从原用户转移到主账户' do
      existing_user = create(:app_user, phone: '13900139002')
      device = create(:device, app_user: user)
      device_id = device.device_id
      create(:sms_verification, phone: '13900139002', code: '7777', expires_at: 5.minutes.from_now)

      post '/api/app_users/login_by_code', params: { uuid: user.uuid, phone: '13900139002', code: '7777' }

      expect(response).to have_http_status(:success)
      # 设备已绑定到主账户
      expect(Device.find_by(device_id: device_id).app_user_id).to eq(existing_user.id)
    end

    it '主账户已有 openid 时不受影响' do
      existing_user = create(:app_user, phone: '13900139003', wechat_openid: 'oMAIN_ACCOUNT')
      user.update!(phone: nil, wechat_openid: 'oDEVICE_USER')
      create(:sms_verification, phone: '13900139003', code: '8888', expires_at: 5.minutes.from_now)

      post '/api/app_users/login_by_code', params: { uuid: user.uuid, phone: '13900139003', code: '8888' }

      expect(response).to have_http_status(:success)
      # 主账户的 openid 保持不变
      expect(existing_user.reload.wechat_openid).to eq('oMAIN_ACCOUNT')
    end
  end

  # ==================== 密码登录 ====================
  describe 'POST /api/app_users/login_by_password' do
    it '密码正确登录成功' do
      post '/api/app_users/login_by_password', params: { uuid: user.uuid, phone: user.phone, password: 'password123' }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user][:phone]).to eq(user.phone)
    end

    it '用户未注册返回错误' do
      post '/api/app_users/login_by_password', params: { uuid: 'invalid_uuid', phone: user.phone, password: 'password123' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('用户未注册，请先调用 create_by_device')
    end

    it '密码错误返回错误' do
      post '/api/app_users/login_by_password', params: { uuid: user.uuid, phone: user.phone, password: 'wrong_password' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('手机号或密码错误')
    end

    it '手机号不存在返回错误' do
      post '/api/app_users/login_by_password', params: { uuid: user.uuid, phone: '19900001111', password: 'password123' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('手机号或密码错误')
    end
  end

  # ==================== 微信登录 ====================
  describe 'POST /api/app_users/login_by_wechat' do
    let(:wechat_code) { 'wechat_auth_code_123' }
    let(:wechat_openid) { 'oABC1234567890xyz' }

    around do |example|
      ENV['WECHAT_APP_ID'] = 'wx_test_id'
      ENV['WECHAT_APP_SECRET'] = 'wx_test_secret'
      example.run
      ENV.delete('WECHAT_APP_ID')
      ENV.delete('WECHAT_APP_SECRET')
    end

    before do
      allow_any_instance_of(WechatAuthService).to receive(:get_openid).with(wechat_code).and_return(wechat_openid)
    end

    it '首次微信登录绑定微信 openid（有手机号）' do
      post '/api/app_users/login_by_wechat', params: { uuid: user.uuid, code: wechat_code }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      user.reload
      expect(user.wechat_openid).to eq(wechat_openid)
    end

    it '用户未注册返回错误' do
      post '/api/app_users/login_by_wechat', params: { uuid: 'invalid_uuid', code: wechat_code }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('用户未注册，请先调用 create_by_device')
    end

    it '用户无手机号时返回绑定手机提示' do
      user.update!(phone: nil, wechat_openid: nil)
      allow_any_instance_of(WechatAuthService).to receive(:get_openid).with(wechat_code).and_return('new_openid_123')

      post '/api/app_users/login_by_wechat', params: { uuid: user.uuid, code: wechat_code }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('请绑定手机号')
      # openid 已被更新
      expect(user.reload.wechat_openid).to eq('new_openid_123')
    end

    it '再次微信登录时覆盖更新 openid' do
      # 首次登录
      post '/api/app_users/login_by_wechat', params: { uuid: user.uuid, code: wechat_code }
      expect(user.reload.wechat_openid).to eq(wechat_openid)

      # 第二次登录，使用新的 openid
      new_openid = 'oNEW9999999999abc'
      allow_any_instance_of(WechatAuthService).to receive(:get_openid).with(wechat_code).and_return(new_openid)

      post '/api/app_users/login_by_wechat', params: { uuid: user.uuid, code: wechat_code }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(user.reload.wechat_openid).to eq(new_openid)
    end

    it 'openid 被其他用户占用时，覆盖到当前用户并清空其他用户' do
      other_user = create(:app_user, wechat_openid: wechat_openid)

      post '/api/app_users/login_by_wechat', params: { uuid: user.uuid, code: wechat_code }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)

      # 当前用户的 openid 被更新
      expect(user.reload.wechat_openid).to eq(wechat_openid)
      # 其他用户的 openid 被清空
      expect(other_user.reload.wechat_openid).to be_nil
    end

    it '微信授权码已被使用时返回友好提示而非500' do
      # 模拟微信返回 code been used 错误
      allow_any_instance_of(WechatAuthService).to receive(:get_openid).with(wechat_code).and_raise(StandardError, 'code been used')

      post '/api/app_users/login_by_wechat', params: { uuid: user.uuid, code: wechat_code }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('授权已过期，请重新授权登录')
    end
  end

  # ==================== QQ登录 ====================
  describe 'POST /api/app_users/login_by_qq' do
    let(:qq_code) { 'qq_auth_code_456' }
    let(:qq_openid) { 'QQ_OPENID_ABC123' }

    around do |example|
      ENV['QQ_APP_ID'] = 'qq_test_id'
      ENV['QQ_APP_KEY'] = 'qq_test_key'
      example.run
      ENV.delete('QQ_APP_ID')
      ENV.delete('QQ_APP_KEY')
    end

    before do
      allow_any_instance_of(QqAuthService).to receive(:get_openid_by_code).with(qq_code).and_return(qq_openid)
    end

    it '首次QQ登录绑定QQopenid' do
      post '/api/app_users/login_by_qq', params: { uuid: user.uuid, code: qq_code }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      user.reload
      expect(user.qq_openid).to eq(qq_openid)
    end

    it '用户未注册返回错误' do
      post '/api/app_users/login_by_qq', params: { uuid: 'invalid_uuid', code: qq_code }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('用户未注册，请先调用 create_by_device')
    end
  end

  # ==================== 头像签名 ====================
  describe 'avatar URL 签名' do
    it '返回带签名的 OSS avatar URL' do
      head_img = create(:head_img, img_url: 'https://zheli.oss-cn-beijing.aliyuncs.com/test/avatar.png')
      user.update!(head_img_id: head_img.id)

      put '/api/app_users/update_profile',
          params: { uuid: user.uuid, nickname: '测试' },
          as: :json

      expect(response).to have_http_status(200)
      avatar = json_response[:response][:data][:user][:avatar]
      expect(avatar).to be_a(Hash)
      expect(avatar[:id]).to eq(head_img.id)
      expect(avatar[:img_url]).to include('Expires=')
      expect(avatar[:img_url]).to include('Signature=')
    end

    it '中文路径的 avatar URL 也能正常签名' do
      head_img = create(:head_img, img_url: 'https://zheli.oss-cn-beijing.aliyuncs.com/小老虎历险记/avatar.png')
      user.update!(head_img_id: head_img.id)

      put '/api/app_users/update_profile',
          params: { uuid: user.uuid, nickname: '测试' },
          as: :json

      expect(response).to have_http_status(200)
      avatar = json_response[:response][:data][:user][:avatar]
      expect(avatar[:img_url]).to include('Expires=')
      expect(avatar[:img_url]).to include('Signature=')
    end

    it 'avatar 为 nil 时返回 nil' do
      user.update!(head_img_id: nil)

      put '/api/app_users/update_profile',
          params: { uuid: user.uuid, nickname: '测试' },
          as: :json

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:user][:avatar]).to be_nil
    end
  end

  # ==================== 更新用户资料 ====================
  describe 'PUT /api/app_users/update_profile' do
    context '更新昵称' do
      it '成功更新昵称' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, nickname: '新昵称' },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:nickname]).to eq('新昵称')
      end

      it '返回更新后的用户信息' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, nickname: '测试昵称' },
            as: :json

        expect(json_response[:response][:data][:user][:id]).to eq(user.id)
        expect(json_response[:response][:data][:user][:uuid]).to eq(user.uuid)
      end
    end

    context '更新年纪' do
      it '成功更新年纪' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, grade_id: 6 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(6)
      end

      it '可以更新为0岁' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, grade_id: 0 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(0)
      end

      it '可以同时更新昵称和年纪' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, nickname: '小明', grade_id: 8 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:nickname]).to eq('小明')
        expect(json_response[:response][:data][:user][:grade_id]).to eq(8)
      end
    end

    context '参数校验' do
      it '两个字段都为空时返回错误' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it '只有空字符串昵称时返回错误' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, nickname: '' },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context '更新头像' do
      it '非VIP用户可以更新普通头像' do
        head_img = create(:head_img, is_vip: false)

        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, head_img_id: head_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.head_img_id).to eq(head_img.id)
      end

      it '非VIP用户不能更新VIP头像' do
        vip_img = create(:head_img, is_vip: true)

        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, head_img_id: vip_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include('VIP')
      end

      it 'VIP用户可以更新VIP头像' do
        vip_img = create(:head_img, is_vip: true)
        user.update!(is_vip: true, vip_expires_at: 30.days.from_now)

        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, head_img_id: vip_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.head_img_id).to eq(vip_img.id)
      end

      it '不存在的头像ID返回错误' do
        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, head_img_id: 99_999 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include('头像不存在')
      end

      it '返回用户信息时包含头像entity' do
        head_img = create(:head_img, is_vip: false)
        user.update!(head_img_id: head_img.id)

        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, head_img_id: head_img.id },
            as: :json

        expect(response).to have_http_status(200)
        avatar = json_response[:response][:data][:user][:avatar]
        expect(avatar).to be_a(Hash)
        expect(avatar[:id]).to eq(head_img.id)
        expect(avatar[:img_url]).to include('Expires=')
        expect(avatar[:img_url]).to include('Signature=')
      end

      it '用户没有头像时 avatar 返回 nil' do
        user.update!(head_img_id: nil)

        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, nickname: '测试' },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:avatar]).to be_nil
      end

      it '可以同时更新昵称、年纪和头像' do
        head_img = create(:head_img, is_vip: false)

        put '/api/app_users/update_profile',
            params: { uuid: user.uuid, nickname: '新昵称', grade_id: 5, head_img_id: head_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        data = json_response[:response][:data][:user]
        expect(data[:nickname]).to eq('新昵称')
        expect(data[:grade_id]).to eq(5)
        expect(data[:avatar]).to be_a(Hash)
        expect(data[:avatar][:img_url]).to include('Expires=')
      end
    end

    context '未授权' do
      it '无效uuid返回错误' do
        put '/api/app_users/update_profile',
            params: { uuid: 'nonexistent-uuid', nickname: 'test' },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end
  end

  # ==================== 设置/重置密码 ====================
  describe 'POST /api/app_users/reset_password' do
    context '首次设置密码（用户没有密码）' do
      it '需要提供手机号，不需要验证码' do
        user = AppUser.create!(phone: '13800138000') # 不设置密码
        post '/api/app_users/reset_password',
             params: { uuid: user.uuid, password: 'NewPass123', phone: '13800138000' },
             as: :json

        expect(response).to have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.password_digest).to be_present
      end

      it '不提供手机号返回错误' do
        user = AppUser.create! # 不设置密码
        post '/api/app_users/reset_password',
             params: { uuid: user.uuid, password: 'NewPass123' },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include('手机号')
      end

      it '手机号未绑定账户返回错误' do
        user = AppUser.create!
        post '/api/app_users/reset_password',
             params: { uuid: user.uuid, password: 'NewPass123', phone: '19900000000' },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it '用户未注册时返回错误' do
        post '/api/app_users/reset_password',
             params: { uuid: 'nonexistent-uuid', password: 'NewPass123' },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context '修改已有密码' do
      it '必须提供手机号和验证码' do
        user = create(:app_user)

        post '/api/app_users/reset_password',
             params: { uuid: user.uuid, password: 'NewPass123' },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include('手机号')
      end

      it '提供正确的手机号和验证码后可以修改密码' do
        user = create(:app_user, phone: '13800138000')
        create(:sms_verification, phone: '13800138000', code: '1234')

        post '/api/app_users/reset_password',
             params: {
               uuid: user.uuid,
               password: 'NewPass123',
               phone: '13800138000',
               code: '1234'
             },
             as: :json

        expect(response).to have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.authenticate('NewPass123')).to eq(user)
      end

      it '验证码错误时返回错误' do
        user = create(:app_user, phone: '13800138000')
        create(:sms_verification, phone: '13800138000', code: '1234')

        post '/api/app_users/reset_password',
             params: {
               uuid: user.uuid,
               password: 'NewPass123',
               phone: '13800138000',
               code: '9999'
             },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it '手机号不匹配时返回错误' do
        user = create(:app_user, phone: '13800138000')
        create(:sms_verification, phone: '13900139000', code: '1234')

        post '/api/app_users/reset_password',
             params: {
               uuid: user.uuid,
               password: 'NewPass123',
               phone: '13900139000',
               code: '1234'
             },
             as: :json

        expect(response).to have_http_status(200)
      end
    end
  end

  # ==================== 退出登录 ====================
  describe 'POST /api/app_users/logout' do
    let!(:device) { create(:device, app_user: user) }

    before do
      # 清除 factory 创建的默认设备，只保留测试用的 device
      user.devices.where.not(device_id: device.device_id).destroy_all
    end

    it '解绑旧设备并返回新用户的 uuid' do
      old_uuid = user.uuid

      post '/api/app_users/logout', params: { uuid: old_uuid }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
      new_uuid = json_response[:response][:data][:user][:uuid]
      expect(new_uuid).to be_present
      expect(new_uuid).not_to eq(old_uuid)
    end

    it '解绑旧设备后设备重新绑定到新用户' do
      device.device_id

      post '/api/app_users/logout', params: { uuid: user.uuid }

      new_user = AppUser.last
      expect(device.reload.app_user_id).to eq(new_user.id)
      expect(device.reload.app_user_id).not_to eq(user.id)
    end

    it '旧用户账户仍然存在' do
      user_id = user.id

      post '/api/app_users/logout', params: { uuid: user.uuid }

      expect(AppUser.find_by(id: user_id)).to be_present
    end

    it '无效 uuid 返回未授权' do
      post '/api/app_users/logout', params: { uuid: 'invalid_uuid_00000' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
      expect(json_response[:response][:msg]).to eq('未授权访问')
    end

    it '用户没有设备也能正常创建新用户' do
      user.devices.destroy_all

      post '/api/app_users/logout', params: { uuid: user.uuid }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:data][:user][:uuid]).to be_present
    end

    it '退出后新用户可以继续使用该设备' do
      post '/api/app_users/logout', params: { uuid: user.uuid }

      new_uuid = json_response[:response][:data][:user][:uuid]
      # 用新 uuid 再次退出
      post '/api/app_users/logout', params: { uuid: new_uuid }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:data][:user][:uuid]).not_to eq(new_uuid)
    end
  end

  # ==================== 注销账户 ====================
  describe 'POST /api/app_users/delete_account' do
    it '成功注销账户，用户记录被删除' do
      user_id = user.id
      user_uuid = user.uuid

      post '/api/app_users/delete_account', params: { uuid: user_uuid }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:msg]).to eq('账户已注销')
      expect(AppUser.find_by(id: user_id)).to be_nil
      expect(AppUser.find_by(uuid: user_uuid)).to be_nil
    end

    it '注销后返回新的匿名用户信息' do
      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      expect(response).to have_http_status(201)
      data = json_response[:response][:data]
      expect(data[:user]).to be_present
      expect(data[:user][:uuid]).to be_present
      expect(data[:user][:uuid]).not_to eq(user.uuid)
      expect(data[:user][:phone]).to be_nil
    end

    it '注销后原 uuid 无法再查询到用户' do
      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      get '/api/app_users/info', params: { uuid: user.uuid }
      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
    end

    it '所有关联资源被删除（书架、书签、会员、订单、阅读记录等）' do
      book = create(:book)
      create(:bookshelf, app_user: user, book: book)
      create(:bookmark, app_user: user, book: book)
      create(:membership, app_user: user)
      create(:order, app_user: user)
      create(:reading_session, app_user: user)
      create(:reading_progress, app_user: user)
      create(:user_reading_daily_stats, app_user: user)
      create(:parental_control, app_user: user, time_limit_minutes: 30)

      user_id = user.id

      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      expect(Bookshelf.where(app_user_id: user_id)).to eq([])
      expect(Bookmark.where(app_user_id: user_id)).to eq([])
      expect(Membership.where(app_user_id: user_id)).to eq([])
      expect(Order.where(app_user_id: user_id)).to eq([])
      expect(ReadingSession.where(app_user_id: user_id)).to eq([])
      expect(ReadingProgress.where(app_user_id: user_id)).to eq([])
      expect(UserReadingDailyStats.where(app_user_id: user_id)).to eq([])
      expect(ParentalControl.where(app_user_id: user_id)).to eq([])
    end

    it '多设备场景 — 所有设备被解绑并创建新的匿名用户' do
      device1 = create(:device, app_user: user)
      device2 = create(:device, app_user: user)
      device3 = create(:device, app_user: user)
      device_ids = [device1.device_id, device2.device_id, device3.device_id]

      old_user_id = user.id

      expect do
        post '/api/app_users/delete_account', params: { uuid: user.uuid }
      end.to change(AppUser, :count).by(3)

      expect(response).to have_http_status(201)

      # 原用户被删除
      expect(AppUser.find_by(id: old_user_id)).to be_nil

      # 每个设备都绑定到了新的匿名用户
      device_ids.each do |device_id|
        device = Device.find_by(device_id: device_id)
        expect(device.app_user).to be_present
        expect(device.app_user.id).not_to eq(old_user_id)
      end

      # 三个设备绑定到三个不同的新账户
      new_user_ids = device_ids.map { |did| Device.find_by(device_id: did).app_user_id }.uniq
      expect(new_user_ids.size).to eq(3)
    end

    it '用户有两个设备时，每个设备获得独立的新账户（模拟多设备登录踢下线）' do
      # 模拟：设备 A 和设备 B 都通过手机号登录到同一个账户
      phone = '13800138099'
      user.update!(phone: phone)

      device_a = create(:device, app_user: user, device_id: 'device_a_delete_test')
      device_b = create(:device, app_user: user, device_id: 'device_b_delete_test')

      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      # 两个设备都被重新绑定到新的匿名用户
      new_user_a = Device.find_by(device_id: device_a.device_id).app_user
      new_user_b = Device.find_by(device_id: device_b.device_id).app_user

      expect(new_user_a).to be_present
      expect(new_user_b).to be_present
      expect(new_user_a.id).not_to eq(new_user_b.id)
      # 新账户没有手机号（匿名用户）
      expect(new_user_a.phone).to be_nil
      expect(new_user_b.phone).to be_nil
    end

    it '用户无设备时也能正常注销' do
      user.devices.destroy_all
      user_id = user.id

      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
      expect(AppUser.find_by(id: user_id)).to be_nil
      # 没有创建新用户（因为没有设备）
      expect(AppUser.count).to eq(0)
      # 没有设备时返回 user 为 nil
      expect(json_response[:response][:data][:user]).to be_nil
    end

    it 'VIP 用户注销 — 会员记录也被删除' do
      create(:membership, app_user: user)
      user.update!(is_vip: true, vip_expires_at: 30.days.from_now)

      user_id = user.id

      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      expect(AppUser.find_by(id: user_id)).to be_nil
      expect(Membership.where(app_user_id: user_id)).to eq([])
    end

    it '有家长管控的用户注销 — 管控记录也被删除' do
      create(:parental_control, app_user: user, time_limit_minutes: 60)
      user_id = user.id

      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      expect(ParentalControl.where(app_user_id: user_id)).to eq([])
    end

    it '无效 uuid 返回未授权' do
      post '/api/app_users/delete_account', params: { uuid: 'invalid_uuid_00000' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
      expect(json_response[:response][:msg]).to eq('未授权访问')
    end

    it '有书架图书的用户注销 — 书架记录被删除' do
      book = create(:book)
      create(:bookshelf, app_user: user, book: book, reading_progress: 50.0)
      user_id = user.id

      post '/api/app_users/delete_account', params: { uuid: user.uuid }

      expect(Bookshelf.where(app_user_id: user_id)).to eq([])
      # 图书本身不被删除
      expect(Book.find_by(id: book.id)).to be_present
    end
  end

  # ==================== 多设备共享 ====================
  describe '多设备共享同一账户' do
    it '新设备创建新账户' do
      expect do
        post '/api/app_users/create_by_device', params: { device_id: 'new_device_abc123' }
      end.to change(AppUser, :count).by(1).and change(Device, :count).by(1)
    end

    it '已存在的设备返回已有账户' do
      device = user.devices.first
      post '/api/app_users/create_by_device', params: { device_id: device.device_id }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user][:id]).to eq(user.id)
    end

    it '已解绑的设备重新调用 create_by_device 会创建新用户并绑定' do
      device = create(:device, app_user: user)
      device.update_column(:app_user_id, nil)

      expect do
        post '/api/app_users/create_by_device', params: { device_id: device.device_id }
      end.to change(AppUser, :count).by(1)

      expect(response).to have_http_status(:created)
      new_user = AppUser.last
      expect(device.reload.app_user_id).to eq(new_user.id)
    end

    it '设备A绑定手机号后，设备B用同一手机号登录共享账户' do
      phone = '13800138000'
      create(:sms_verification, phone: phone, code: '1234', expires_at: 5.minutes.from_now)

      device_a = Device.create!(device_id: 'device_a_multi_test', app_user: create(:app_user))
      user_a = device_a.app_user
      post '/api/app_users/login_by_code', params: { uuid: user_a.uuid, phone: phone, code: '1234' }
      user_a = json_response[:response][:data][:user]

      create(:sms_verification, phone: phone, code: '5678', expires_at: 5.minutes.from_now)
      device_b = Device.create!(device_id: 'device_b_multi_test', app_user: create(:app_user))
      user_b = device_b.app_user
      post '/api/app_users/login_by_code', params: { uuid: user_b.uuid, phone: phone, code: '5678' }
      user_b = json_response[:response][:data][:user]

      expect(user_a[:id]).to eq(user_b[:id])
      expect(user_a[:phone]).to eq(phone)
      expect(user_b[:phone]).to eq(phone)
    end

    it '设备B用手机号+密码登录已有账户' do
      phone = '13700137000'
      device_a = Device.create!(device_id: 'device_a_pwd_test', app_user: create(:app_user))
      user_a = device_a.app_user
      create(:sms_verification, phone: phone, code: '9999', expires_at: 5.minutes.from_now)
      post '/api/app_users/login_by_code', params: { uuid: user_a.uuid, phone: phone, code: '9999' }
      account_id = json_response[:response][:data][:user][:id]

      create(:sms_verification, phone: phone, code: '8888', expires_at: 5.minutes.from_now)
      post '/api/app_users/reset_password', params: { uuid: user_a.uuid, phone: phone, code: '8888', password: 'mypassword' }

      device_b = Device.create!(device_id: 'device_b_pwd_test', app_user: create(:app_user))
      user_b = device_b.app_user
      post '/api/app_users/login_by_password', params: { uuid: user_b.uuid, phone: phone, password: 'mypassword' }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user][:id]).to eq(account_id)
    end

    it '设备A是VIP，设备B登录后也共享VIP状态' do
      phone = '13600136000'
      device_a = Device.create!(device_id: 'device_a_vip_test', app_user: create(:app_user))
      user_a = device_a.app_user
      create(:sms_verification, phone: phone, code: '4444', expires_at: 5.minutes.from_now)
      post '/api/app_users/login_by_code', params: { uuid: user_a.uuid, phone: phone, code: '4444' }
      AppUser.find(json_response[:response][:data][:user][:id]).update!(is_vip: true, vip_expires_at: 30.days.from_now)

      create(:sms_verification, phone: phone, code: '5555', expires_at: 5.minutes.from_now)
      device_b = Device.create!(device_id: 'device_b_vip_test', app_user: create(:app_user))
      user_b = device_b.app_user
      post '/api/app_users/login_by_code', params: { uuid: user_b.uuid, phone: phone, code: '5555' }

      expect(json_response[:response][:data][:user][:is_vip]).to be true
    end
  end
end
