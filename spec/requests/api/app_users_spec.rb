# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API AppUsers", type: :request do
  let(:user) { create(:app_user) }

  # ==================== 创建设备用户 ====================
  describe "POST /api/app_users/create_by_device" do
    it "创建新用户并默认三年级" do
      post "/api/app_users/create_by_device",
           params: { device_id: "test-device-123" },
           as: :json

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:code]).to eq(0)
      user_data = body[:data][:user]
      expect(user_data[:uuid]).to be_present

      created_user = AppUser.find_by(uuid: user_data[:uuid])
      expect(created_user.grade_id).to eq(Grade.find_by(name: "三年级")&.id)
    end

    it "创建新用户时默认昵称为少年越读者" do
      post "/api/app_users/create_by_device",
           params: { device_id: "test-device-nickname" },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.nickname).to eq('少年越读者')
    end

    it "创建新用户时分配非VIP基础头像" do
      normal_img = create(:head_img, is_vip: false)

      post "/api/app_users/create_by_device",
           params: { device_id: "test-device-head-img" },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.head_img).to eq(normal_img)
    end

    it "没有可用非VIP头像时创建用户不报错" do
      HeadImg.destroy_all

      post "/api/app_users/create_by_device",
           params: { device_id: "test-device-no-img" },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.head_img_id).to be_nil
    end

    it "VIP头像不能作为默认头像" do
      vip_img = create(:head_img, is_vip: true)

      post "/api/app_users/create_by_device",
           params: { device_id: "test-device-vip-img" },
           as: :json

      expect(response).to have_http_status(:created)
      created_user = AppUser.last
      expect(created_user.head_img_id).to be_nil
    end

    it "已存在设备时返回已有用户" do
      existing_user = create(:app_user)
      device = create(:device, device_id: "existing-device", app_user: existing_user)

      post "/api/app_users/create_by_device",
           params: { device_id: "existing-device" },
           as: :json

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:data][:user][:uuid]).to eq(existing_user.uuid)
    end
  end

  # ==================== 发送验证码 ====================
  describe "POST /api/app_users/send_code" do
    before do
      allow_any_instance_of(AliyunSmsService).to receive(:send_verification_code).and_return(true)
    end

    it "发送验证码成功" do
      post "/api/app_users/send_code", params: { uuid: user.uuid, phone: "13800138001" }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "手机号格式不正确返回错误" do
      post "/api/app_users/send_code", params: { uuid: user.uuid, phone: "123" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("手机号格式不正确")
    end
  end

  # ==================== 用户配置 ====================
  describe "GET /api/app_users/config" do
    it "无家长控制时返回 time_limit_minutes 为 0" do
      get "/api/app_users/config", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:time_limit_minutes]).to eq(0)
    end

    it "有家长控制时返回限制时间" do
      create(:parental_control, app_user: user, time_limit_minutes: 60)

      get "/api/app_users/config", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:time_limit_minutes]).to eq(60)
    end

    it "无效 uuid 返回未授权" do
      get "/api/app_users/config", params: { uuid: "invalid_uuid_00000" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
    end

    it "uuid 无效返回未授权错误" do
      post "/api/app_users/send_code", params: { uuid: "invalid_uuid", phone: "13800138001" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
      expect(json_response[:response][:msg]).to eq("未授权访问")
    end
  end

  # ==================== 验证码登录 ====================
  describe "POST /api/app_users/login_by_code" do
    let!(:sms_verification) do
      create(:sms_verification, phone: "13800138000", code: "1234", expires_at: 5.minutes.from_now)
    end

    it "登录成功" do
      post "/api/app_users/login_by_code", params: { uuid: user.uuid, phone: "13800138000", code: "1234" }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user]).to be_present
    end

    it "用户未注册返回错误" do
      post "/api/app_users/login_by_code", params: { uuid: "invalid_uuid", phone: "13800138000", code: "1234" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("用户未注册，请先调用 create_by_device")
    end

    it "验证码错误返回错误" do
      post "/api/app_users/login_by_code", params: { uuid: user.uuid, phone: "13800138000", code: "9999" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("验证码无效或已过期")
    end
  end

  # ==================== 密码登录 ====================
  describe "POST /api/app_users/login_by_password" do
    it "密码正确登录成功" do
      post "/api/app_users/login_by_password", params: { uuid: user.uuid, phone: user.phone, password: "password123" }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user][:phone]).to eq(user.phone)
    end

    it "用户未注册返回错误" do
      post "/api/app_users/login_by_password", params: { uuid: "invalid_uuid", phone: user.phone, password: "password123" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("用户未注册，请先调用 create_by_device")
    end

    it "密码错误返回错误" do
      post "/api/app_users/login_by_password", params: { uuid: user.uuid, phone: user.phone, password: "wrong_password" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("手机号或密码错误")
    end

    it "手机号不存在返回错误" do
      post "/api/app_users/login_by_password", params: { uuid: user.uuid, phone: "19900001111", password: "password123" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("手机号或密码错误")
    end
  end

  # ==================== 微信登录 ====================
  describe "POST /api/app_users/login_by_wechat" do
    let(:wechat_code) { "wechat_auth_code_123" }
    let(:wechat_openid) { "oABC1234567890xyz" }

    around do |example|
      ENV["WECHAT_APP_ID"] = "wx_test_id"
      ENV["WECHAT_APP_SECRET"] = "wx_test_secret"
      example.run
      ENV.delete("WECHAT_APP_ID")
      ENV.delete("WECHAT_APP_SECRET")
    end

    before do
      allow_any_instance_of(WechatAuthService).to receive(:get_openid).with(wechat_code).and_return(wechat_openid)
    end

    it "首次微信登录绑定微信openid" do
      post "/api/app_users/login_by_wechat", params: { uuid: user.uuid, code: wechat_code }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      user.reload
      expect(user.wechat_openid).to eq(wechat_openid)
    end

    it "用户未注册返回错误" do
      post "/api/app_users/login_by_wechat", params: { uuid: "invalid_uuid", code: wechat_code }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("用户未注册，请先调用 create_by_device")
    end
  end

  # ==================== QQ登录 ====================
  describe "POST /api/app_users/login_by_qq" do
    let(:qq_code) { "qq_auth_code_456" }
    let(:qq_openid) { "QQ_OPENID_ABC123" }

    around do |example|
      ENV["QQ_APP_ID"] = "qq_test_id"
      ENV["QQ_APP_KEY"] = "qq_test_key"
      example.run
      ENV.delete("QQ_APP_ID")
      ENV.delete("QQ_APP_KEY")
    end

    before do
      allow_any_instance_of(QqAuthService).to receive(:get_openid_by_code).with(qq_code).and_return(qq_openid)
    end

    it "首次QQ登录绑定QQopenid" do
      post "/api/app_users/login_by_qq", params: { uuid: user.uuid, code: qq_code }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      user.reload
      expect(user.qq_openid).to eq(qq_openid)
    end

    it "用户未注册返回错误" do
      post "/api/app_users/login_by_qq", params: { uuid: "invalid_uuid", code: qq_code }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq("用户未注册，请先调用 create_by_device")
    end
  end

  # ==================== 头像签名 ====================
  describe "avatar URL 签名" do
    it "返回带签名的 OSS avatar URL" do
      head_img = create(:head_img, img_url: "https://zheli.oss-cn-beijing.aliyuncs.com/test/avatar.png")
      user.update!(head_img_id: head_img.id)

      put "/api/app_users/update_profile",
          params: { uuid: user.uuid, nickname: "测试" },
          as: :json

      expect(response).to have_http_status(200)
      avatar = json_response[:response][:data][:user][:avatar]
      expect(avatar).to be_a(Hash)
      expect(avatar[:id]).to eq(head_img.id)
      expect(avatar[:img_url]).to include("Expires=")
      expect(avatar[:img_url]).to include("Signature=")
      expect(avatar).to have_key(:is_vip)
    end

    it "中文路径的 avatar URL 也能正常签名" do
      head_img = create(:head_img, img_url: "https://zheli.oss-cn-beijing.aliyuncs.com/小老虎历险记/avatar.png")
      user.update!(head_img_id: head_img.id)

      put "/api/app_users/update_profile",
          params: { uuid: user.uuid, nickname: "测试" },
          as: :json

      expect(response).to have_http_status(200)
      avatar = json_response[:response][:data][:user][:avatar]
      expect(avatar[:img_url]).to include("Expires=")
      expect(avatar[:img_url]).to include("Signature=")
    end

    it "avatar 为 nil 时返回 nil" do
      user.update!(head_img_id: nil)

      put "/api/app_users/update_profile",
          params: { uuid: user.uuid, nickname: "测试" },
          as: :json

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:user][:avatar]).to be_nil
    end
  end

  # ==================== 更新用户资料 ====================
  describe "PUT /api/app_users/update_profile" do
    context "更新昵称" do
      it "成功更新昵称" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "新昵称" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:nickname]).to eq("新昵称")
      end

      it "返回更新后的用户信息" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "测试昵称" },
            as: :json

        expect(json_response[:response][:data][:user][:id]).to eq(user.id)
        expect(json_response[:response][:data][:user][:uuid]).to eq(user.uuid)
      end
    end

    context "更新年纪" do
      it "成功更新年纪" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, grade_id: 6 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(6)
      end

      it "可以更新为0岁" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, grade_id: 0 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(0)
      end

      it "可以同时更新昵称和年纪" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "小明", grade_id: 8 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:nickname]).to eq("小明")
        expect(json_response[:response][:data][:user][:grade_id]).to eq(8)
      end
    end

    context "参数校验" do
      it "两个字段都为空时返回错误" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it "只有空字符串昵称时返回错误" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "更新头像" do
      it "非VIP用户可以更新普通头像" do
        head_img = create(:head_img, is_vip: false)

        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, head_img_id: head_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.head_img_id).to eq(head_img.id)
      end

      it "非VIP用户不能更新VIP头像" do
        vip_img = create(:head_img, is_vip: true)

        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, head_img_id: vip_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include("VIP")
      end

      it "VIP用户可以更新VIP头像" do
        vip_img = create(:head_img, is_vip: true)
        user.update!(is_vip: true, vip_expires_at: 30.days.from_now)

        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, head_img_id: vip_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.head_img_id).to eq(vip_img.id)
      end

      it "不存在的头像ID返回错误" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, head_img_id: 99999 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include("头像不存在")
      end

      it "返回用户信息时包含头像entity" do
        head_img = create(:head_img, is_vip: false)
        user.update!(head_img_id: head_img.id)

        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, head_img_id: head_img.id },
            as: :json

        expect(response).to have_http_status(200)
        avatar = json_response[:response][:data][:user][:avatar]
        expect(avatar).to be_a(Hash)
        expect(avatar[:id]).to eq(head_img.id)
        expect(avatar[:img_url]).to include("Expires=")
        expect(avatar[:img_url]).to include("Signature=")
        expect(avatar[:is_vip]).to eq(false)
      end

      it "用户没有头像时 avatar 返回 nil" do
        user.update!(head_img_id: nil)

        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "测试" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:avatar]).to be_nil
      end

      it "可以同时更新昵称、年纪和头像" do
        head_img = create(:head_img, is_vip: false)

        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "新昵称", grade_id: 5, head_img_id: head_img.id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        data = json_response[:response][:data][:user]
        expect(data[:nickname]).to eq("新昵称")
        expect(data[:grade_id]).to eq(5)
        expect(data[:avatar]).to be_a(Hash)
        expect(data[:avatar][:img_url]).to include("Expires=")
      end
    end

    context "未授权" do
      it "无效uuid返回错误" do
        put "/api/app_users/update_profile",
            params: { uuid: "nonexistent-uuid", nickname: "test" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end
  end

  # ==================== 设置/重置密码 ====================
  describe "POST /api/app_users/reset_password" do
    context "首次设置密码（用户没有密码）" do
      it "只需要 uuid 和 password，不需要手机号和验证码" do
        user = AppUser.create! # 不设置密码
        post "/api/app_users/reset_password",
             params: { uuid: user.uuid, password: "NewPass123" },
             as: :json

        expect(response).to have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.password_digest).to be_present
      end

      it "用户未注册时返回错误" do
        post "/api/app_users/reset_password",
             params: { uuid: "nonexistent-uuid", password: "NewPass123" },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "修改已有密码" do
      it "必须提供手机号和验证码" do
        user = create(:app_user)

        post "/api/app_users/reset_password",
             params: { uuid: user.uuid, password: "NewPass123" },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include("手机号")
      end

      it "提供正确的手机号和验证码后可以修改密码" do
        user = create(:app_user, phone: "13800138000")
        create(:sms_verification, phone: "13800138000", code: "1234")

        post "/api/app_users/reset_password",
             params: {
               uuid: user.uuid,
               password: "NewPass123",
               phone: "13800138000",
               code: "1234"
             },
             as: :json

        expect(response).to have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.authenticate("NewPass123")).to eq(user)
      end

      it "验证码错误时返回错误" do
        user = create(:app_user, phone: "13800138000")
        create(:sms_verification, phone: "13800138000", code: "1234")

        post "/api/app_users/reset_password",
             params: {
               uuid: user.uuid,
               password: "NewPass123",
               phone: "13800138000",
               code: "9999"
             },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it "手机号不匹配时返回错误" do
        user = create(:app_user, phone: "13800138000")
        create(:sms_verification, phone: "13900139000", code: "1234")

        post "/api/app_users/reset_password",
             params: {
               uuid: user.uuid,
               password: "NewPass123",
               phone: "13900139000",
               code: "1234"
             },
             as: :json

        expect(response).to have_http_status(200)
      end
    end
  end

  # ==================== 多设备共享 ====================
  describe "多设备共享同一账户" do
    it "新设备创建新账户" do
      expect do
        post "/api/app_users/create_by_device", params: { device_id: "new_device_abc123" }
      end.to change(AppUser, :count).by(1).and change(Device, :count).by(1)
    end

    it "已存在的设备返回已有账户" do
      device = user.devices.first
      post "/api/app_users/create_by_device", params: { device_id: device.device_id }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user][:id]).to eq(user.id)
    end

    it "设备A绑定手机号后，设备B用同一手机号登录共享账户" do
      phone = "13800138000"
      create(:sms_verification, phone: phone, code: "1234", expires_at: 5.minutes.from_now)

      device_a = Device.create!(device_id: "device_a_multi_test", app_user: create(:app_user))
      user_a = device_a.app_user
      post "/api/app_users/login_by_code", params: { uuid: user_a.uuid, phone: phone, code: "1234" }
      user_a = json_response[:response][:data][:user]

      create(:sms_verification, phone: phone, code: "5678", expires_at: 5.minutes.from_now)
      device_b = Device.create!(device_id: "device_b_multi_test", app_user: create(:app_user))
      user_b = device_b.app_user
      post "/api/app_users/login_by_code", params: { uuid: user_b.uuid, phone: phone, code: "5678" }
      user_b = json_response[:response][:data][:user]

      expect(user_a[:id]).to eq(user_b[:id])
      expect(user_a[:phone]).to eq(phone)
      expect(user_b[:phone]).to eq(phone)
    end

    it "设备B用手机号+密码登录已有账户" do
      phone = "13700137000"
      device_a = Device.create!(device_id: "device_a_pwd_test", app_user: create(:app_user))
      user_a = device_a.app_user
      create(:sms_verification, phone: phone, code: "9999", expires_at: 5.minutes.from_now)
      post "/api/app_users/login_by_code", params: { uuid: user_a.uuid, phone: phone, code: "9999" }
      account_id = json_response[:response][:data][:user][:id]

      create(:sms_verification, phone: phone, code: "8888", expires_at: 5.minutes.from_now)
      post "/api/app_users/reset_password", params: { uuid: user_a.uuid, phone: phone, code: "8888", password: "mypassword" }

      device_b = Device.create!(device_id: "device_b_pwd_test", app_user: create(:app_user))
      user_b = device_b.app_user
      post "/api/app_users/login_by_password", params: { uuid: user_b.uuid, phone: phone, password: "mypassword" }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user][:id]).to eq(account_id)
    end

    it "设备A是VIP，设备B登录后也共享VIP状态" do
      phone = "13600136000"
      device_a = Device.create!(device_id: "device_a_vip_test", app_user: create(:app_user))
      user_a = device_a.app_user
      create(:sms_verification, phone: phone, code: "4444", expires_at: 5.minutes.from_now)
      post "/api/app_users/login_by_code", params: { uuid: user_a.uuid, phone: phone, code: "4444" }
      AppUser.find(json_response[:response][:data][:user][:id]).update!(is_vip: true, vip_expires_at: 30.days.from_now)

      create(:sms_verification, phone: phone, code: "5555", expires_at: 5.minutes.from_now)
      device_b = Device.create!(device_id: "device_b_vip_test", app_user: create(:app_user))
      user_b = device_b.app_user
      post "/api/app_users/login_by_code", params: { uuid: user_b.uuid, phone: phone, code: "5555" }

      expect(json_response[:response][:data][:user][:is_vip]).to be true
    end
  end
end
