
class User {

	//该用户是否需要先注册弹弹play账号才可正常登录。当此值为true时表示用户使用了QQ微博等第三方登录但没有注册弹弹play账号。
	bool registerRequired = false;
	//用户编号
	int userId = 0;
	//弹弹play用户名。如果用户使用第三方账号登录（如QQ微博）且没有关联弹弹play账号，此属性将为null
	String userName;
	//旧API中使用的数字形式的token，仅为兼容性设置，不要在新代码中使用此属性
	int legacyTokenNumber;
	//字符串形式的JWT token。将来调用需要验证权限的接口时，需要在HTTP Authorization头中设置“Bearer token”。
	String token;
	//JWT token过期时间，默认为21天。如果是APP应用开发者账号使用自己的应用登录则为1年。
	String tokenExpireTime;
	//用户注册来源类型
	String userType;
	//昵称
	String screenName;
	//头像图片的地址
	String profileImage;
	//当前登录会话内应用权限列表，可以由此判断能否调用哪些API
	String appScope;

	User.fromJsonMap(Map<String, dynamic> map) {
		try {
			registerRequired = map["registerRequired"];
			userId = map["userId"];
			userName = map["userName"];
			if (map["legacyTokenNumber"] is int) {
				legacyTokenNumber = map["legacyTokenNumber"];
			}
			token = map["token"];
			tokenExpireTime = map["tokenExpireTime"];
			userType = map["userType"];
			screenName = map["screenName"];
			profileImage = map["profileImage"];
			appScope = map["appScope"];
		} catch (e) {
			print(e);
		}

	}


	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['registerRequired'] = registerRequired;
		data['userId'] = userId;
		data['userName'] = userName;
		data['legacyTokenNumber'] = legacyTokenNumber;
		data['token'] = token;
		data['tokenExpireTime'] = tokenExpireTime;
		data['userType'] = userType;
		data['screenName'] = screenName;
		data['profileImage'] = profileImage;
		data['appScope'] = appScope;
		return data;
	}
}
