require 'sinatra/base'
require 'sinatra/reloader'
require 'rack-flash'
require 'haml'

require_relative 'models/users'
require_relative 'lib/arp_scan'

class WebApp < Sinatra::Base
  use Rack::Flash
  register Sinatra::Reloader

  enable :sessions
  enable :method_override

  set :haml, :format => :html5
  set :static_cache_control, [:public, :max_age => 86400] # 1day

  helpers do
    # アラート要素の生成
    def create_alert(type, message)
      haml :alert, :locals => {type: type, message: message}
    end
  end

  not_found do
    haml :not_found
  end

  # サインアップ画面
  get '/signup' do
    haml :signup
  end

  # サインアップ処理
  post '/signup' do
    user = User.new
    user.identifier = @params['user-id']
    user.name       = @params['user-name']
    user.store_password(@params['user-password'])
    if user.valid?
      user.save
      session[:user_id] = user._id
      redirect to('/')
    else
      @messages = user.errors.messages.map{|field, msgs| msgs.last}
      halt 403, (haml :signup)
    end
  end

  # ログアウト画面
  get '/logout' do
    if session[:user_id]
      haml :logout
    else
      halt 403, (haml :unauthorized)
    end
  end

  # ログアウト処理
  delete '/session' do
    session[:user_id] = nil
    redirect to('/')
  end

  # ログイン画面
  get '/login' do
    haml :login
  end

  # ログイン処理
  post '/session' do
    if identifier = @params['user-id'] and password = @params['user-password']
      if user = User.authenticate(identifier, {:method => :password, :password => password})
        session[:user_id] = user._id
        redirect to('/')
      end
    end
    halt 403, (haml :login, :locals => {:failed => true})
  end

  # ログイン中メンバー一覧
  get '/' do
    if session[:user_id]
      User.update_status
      haml :members
    else
      haml :start
    end
  end

  # ユーザの管理ページ
  get '/settings' do
    if session[:user_id]
      @user = User.where(:_id => session[:user_id]).first
      @success = true if flash[:success]
      @messages = flash[:messages] if flash[:messages]
      haml :settings
    else
      halt 403, (haml :unauthorized)
    end
  end

  # ユーザの設定更新
  put '/settings/user' do
    halt 403, (haml :unauthorized) unless session[:user_id]
    @user = User.where(:_id => session[:user_id]).first

    @user.name = @params['user-name']              if @params['user-name']
    @user.store_password(@params['user-password']) if @params['user-password']

    if @user.valid?
      @user.save
      flash[:success] = true
      redirect to('/settings')
    else
      flash[:messages] = @user.errors.messages.map{|field, msgs| msgs.last }
      redirect to('/settings')
    end
  end

  # ホストの生成処理
  post '/settings/host' do
    halt 403, (haml :unauthorized) unless session[:user_id]
    @user = User.where(:_id => session[:user_id]).first
    @user.append_host(@params['host-name'], @params['host-mac'])

    if @user.valid?
      @user.save
      User.update_status(force_update: true, users: [@user])
      flash[:success] = true
      redirect to('/settings')
    else
      flash[:messages] = @user.errors.messages.map{|field, msgs| msgs.last }
      redirect to('/settings')
    end
  end

  # ホストの削除処理
  delete '/settings/host' do
    halt 403, (haml :unauthorized) unless session[:user_id]
    @user = User.where(:_id => session[:user_id]).first
    result = @user.delete_host(@params['host-delete'])

    if @user.valid? and result
      @user.save
      flash[:success] = true
      redirect to('/settings')
    else
      flash[:messages] = ["ホストの指定が正しくありません。"]
      redirect to('/settings')
    end
  end

  # ユーザページ
  get '/user/:id' do
  end
end
