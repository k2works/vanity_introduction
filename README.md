A/BテストフレームワークVanity入門
===
# 目的

# 前提
| ソフトウェア   | バージョン   | 備考        |
|:---------------|:-------------|:------------|
| OS X           |10.8.5        |             |
| ruby           |2.1.1         |             |
| rvm            |1.24.0        |             |
| rbricks        |2.0.5         |             |
| heroku-toolbelt |3.6.0        |             |
| vanity         |1.9.1        |             |
| rails          |4.0.4        |             |

+ [Herokuにサインアップしている](https://id.heroku.com/signup/devcenter)
+ [Heroku Toolbeltをインストールしている](https://toolbelt.heroku.com/)

# 構成
+ [セットアップ](#1)
+ [RailsでA/Bテスト](#2)
+ [Javascriptで参加者登録](#3)
+ [テスト](#4)
+ [Herokuにデプロイする](#5)

# 詳細
## <a name="1">セットアップ</a>
[RailsBricks入門](https://github.com/k2works/rails_bricks_introduction)参照

## <a name="2">RailsでA/Bテスト</a>
### Step 1: RailsアプリケーションでVanityを始める
#### Step 1.1
_Gemfile_
```ruby
gem "vanity"
```
#### Step 1.2
あらかじめredisをインストールしてサーバプロセスを起動しておく
```bash
$ brew install redis
$ redis-server
```
Choose a datastore that best fits your needs and preferences for storing experiment results. Choose one of: Redis, MongoDB or an SQL database. While Redis is usually faster, it may add additional complexity to your stack. Datastores should be configured using a config/vanity.yml.  
実験結果を保存するデータベースを選択する。Redis,MongoDBそしてSQLデータベースからひとつ選ぶ。データベースの設定は_config/vanity.yml_で設定する。

_Gemfile_
```ruby
gem "redis", ">= 2.1"
gem "redis-namespace", ">= 1.1.0"
```
デフォルトではVanityはRedisのローカルホスト、ポート6379に設定されている。

もしデータベースにデータを保存したいなら、ジェネレータを実行してデータベーススキーマを作成する。
```bash
$ rails generate vanity
$ rake db:migrate
```
#### Step 1.3
Vanityを有効にして特定のユーザーを参照できるようにする：
_app/controllers/application_controller.rb_
```ruby
class ApplicationController < ActionController::Base
  use_vanity :current_user
  layout false  # exclude this if you want to use your application layout
end
```
詳細は[ここ](http://vanity.labnotes.org/identity.html)を参考

### Step 2: 最初のA/Bテストを定義する
この実験は_experiments/price_options.rb_ファイルに記述する
```ruby
ab_test "Price options" do
  description "Mirror, mirror on the wall, who's the better price of all?"
  alternatives 19, 25, 29
  metrics :signups
end
```
もし実験に上記の("signups")メトリックスを使うならそれに対応するrubyファイルが必要になる。  
_experiments/metrics/signups.rb_
```ruby
metric "Signup (Activation)" do
  description "Measures how many people signed up for our awesome service."
end
```
### Step 3: ユーザーに違うオプションを提示する
_app/views/pages/home.html.erb_
```
<h2>Get started for only $<%= ab_test :price_options %> a month!</h2>
```
### Step 4: コンバージョンを測定する
コンバージョンは_track!_メソッド経由で作成される  
_app/controllers/sessions_controller.rb_
```ruby
def create
  user = User.where(username: params[:signin][:username].strip).first

  if user && user.authenticate(params[:signin][:password])
    track! :signups
    session[:user_id] = user.id
    redirect_to admin_root_path, notice: "Signed in successfully."
  else
    flash[:error] = "Wrong username/password."
    render :new
  end
end
```
### Step 5: レポートをチェックする
```bash
$ gem install vanity
$ vanity report --output vanity.html
```
Rails3と4ではメトリックスと実験結果をダッシュボードで確認できる
```bash
$ rails generate controller Vanity
```
_config/routes.rb_
```ruby
match '/vanity(/:action(/:id(.:format)))', :controller => :vanity, :via => [:get, :post]
```
_app/controllers/vanity_controller_
```ruby
class VanityController < ApplicationController
  include Vanity::Rails::Dashboard
end
```

## <a name="2">Javascriptで参加者登録</a>

もしロボットやスパイダーがコンバージョン率に大きな影響を与えるようになっているなら。Vanityは非同期Javascriptコールバックでロボットを除いた参加者を計測できるようにオプション設定できる。Vanityはそれらのユーザーエージェントからのリクエストをフィルターする。

To set this up simply do the following:

+ ```Vanity.playground.use_js!``` を追加する  

+ ```Vanity.playground.add_participant_path = '/path/to/vanity/action'```をセットする。これはVanity::Rails::Dashboardで追加されたパスを指し示す。全てのユーザーがアクセスできるようにする（認証を必要としない）

+ ```<%= vanity_js %>``` をab_testを設定したページに追加する。vanity_jsはどのバージョンの実験か知るためにab_testを呼び出した後に読み込む必要がる。このヘルパはab_testが無いページでは何も表示しないのでベージレイアウトの下に配置しておくのは良い方法です。ビューではuse_js!を呼び出しvanity_jsを読み込まないと参加者が記録されないことに注意してください

_app/controllers/application_controller.rb_
```ruby
class ApplicationController < ActionController::Base
  use_vanity :current_user
  Vanity.playground.use_js!
  Vanity.playground.add_participant_path = 'app/controllers/sessions_controller.rb'

```
_app/views/pages/home.html.erb_
```ruby
<% title("Home Page") %>
<h1>Home Page <small>views/pages/home.html.erb</small></h1>
<p>This is your home page. Use the menu at the top to sign in / sign out.</p>
<h2>Get started for only $<%= ab_test :price_options %> a month!</h2>
<%= vanity_js %>
```

## <a name="3">テスト</a>
tests/specsのビューテストや受け入れテストで実験結果を簡単にセットできる。choosesメソッドを使ってください
```ruby
Vanity.playground.experiment(:price_options).chooses(19)
```

## <a name="4">Herokuにデプロイする</a>
_config/vanity.yml_追加
```ruby
development:
  adapter: redis
  connection: redis://localhost:6379/0
test:
  collecting: false
production:
  adapter: redis
  connection: <%= ENV["REDISTOGO_URL"] %>
```
_config/initializers/redis.rb_追加
```ruby
namespace = [Rails.application.class.parent_name, Rails.env].join ':'
if Rails.env.production?
  # herokuの初期 asset compileでENVがうまく読み込まれていないっぽいので対策
  if ENV['REDISCLOUD_URL']
      redis_uri = URI(ENV['REDISCLOUD_URL'])
      Redis.current = Redis.new(host: redis_uri.host, port: redis_uri.port, password: redis_uri.password)
      Redis.current = Redis::Namespace.new(namespace, Redis.new(host: redis_uri.host, port: redis_uri.port, password: redis_uri.password))
  end
else
  Redis.current = Redis::Namespace.new(namespace, Redis.new(host: '127.0.0.1', port: 6379))
end
```
Gem追加
```
# Vanity
gem "vanity"
gem "redis", ">= 2.1"
gem "redis-namespace", ">= 1.1.0"
gem "redis-objects"
```
反映してコミット
```bash
$ bundle
$ git commit -am setup
```
Herokuセットアップ
```bash
$ heroku create --addons heroku-postgresql
$ heroku addons:add redistogo
$ git push heroku master
$ heroku apps:rename vanity-introduction
$ heroku open
```

# 参照
+ [VanityExperimentDriven Development](http://vanity.labnotes.org/)
+ [assaf/vanity](https://github.com/assaf/vanity)
+ [【Redis Cloud無料25MB】Rails4 × Heroku × Redisを超簡単セットアップ！](http://morizyun.github.io/blog/redis-coloud-heroku-rails4-redis-object/)
+ [railsでredis-objectsを使う際にはredis-namespaceも使ったほうがいいかも](http://qiita.com/ichi_s/items/e36b0891c6ca9a9a58f9)
