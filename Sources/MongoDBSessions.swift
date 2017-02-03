//
//  MongoDBSessions.swift
//  Perfect-Session-MongoDB
//
//  Created by Jonathan Guthrie on 2016-12-19.
//
//

import TurnstileCrypto
import MongoDBStORM
import PerfectSession
import PerfectHTTP

public struct MongoDBSessions {

	/// Initializes the Session Manager. No config needed!
	public init() {}


	public func save(session: PerfectSession) {
		var s = session
		s.touch()
		// perform UPDATE
		let proxy = PerfectSessionClass()
		//find
		do {
			try proxy.find(["token":session.token])
			if proxy.results.rows.isEmpty {
				return
			}
			proxy.to(proxy.results.rows[0])
		} catch {
			print("Error retrieving session: \(error)")
		}
		// assign
		proxy.userid = s.userid
		proxy.updated = s.updated
		proxy.idle = SessionConfig.idle // update in case this has changed
		proxy.data = s.data
		proxy.ipaddress = s.ipaddress
		proxy.useragent = s.useragent

		// save
		do {
			try proxy.save()
		} catch {
			print("Error saving session: \(error)")
		}
	}

	public func start(_ request:HTTPRequest) -> PerfectSession {
		let rand = URandom()
		var session = PerfectSession()
		session.token = rand.secureToken
		session.ipaddress = request.remoteAddress.host
		session.useragent = request.header(.userAgent) ?? "unknown"
		session._state = "new"
		session.setCSRF()

		// perform INSERT
		let proxy = PerfectSessionClass(
			token: session.token,
			userid: session.userid,
			created: session.created,
			updated: session.updated,
			idle: session.idle,
			data: session.data,
			ipaddress: session.ipaddress,
			useragent: session.useragent
		)
		try? proxy.save()
		return session
	}

	/// Deletes the session for a session identifier.
	public func destroy(_ request: HTTPRequest, _ response: HTTPResponse) {
		let proxy = PerfectSessionClass()
		do {
			do {
				try proxy.find(["token":(request.session?.token)!])
				proxy.to(proxy.results.rows[0])
			} catch {
				print("Error retrieving session: \(error)")
			}
			try proxy.delete()
		} catch {
			print(error)
		}
		// Reset cookie to make absolutely sure it does not get recreated in some circumstances.
		var domain = ""
		if !SessionConfig.cookieDomain.isEmpty {
			domain = SessionConfig.cookieDomain
		}
		response.addCookie(HTTPCookie(
			name: SessionConfig.name,
			value: "",
			domain: domain,
			expires: .relativeSeconds(SessionConfig.idle),
			path: SessionConfig.cookiePath,
			secure: SessionConfig.cookieSecure,
			httpOnly: SessionConfig.cookieHTTPOnly,
			sameSite: SessionConfig.cookieSameSite
			)
		)
	}

	public func resume(token: String) -> PerfectSession? {
        let proxy = PerfectSessionClass()
        do {
            try proxy.find(["token":token])
            if proxy.results.rows.isEmpty {
                return nil
            }
            proxy.to(proxy.results.rows[0])

            var session = PerfectSession()
            session.token = token
            session.userid = proxy.userid
            session.created = proxy.created
            session.updated = proxy.updated
            session.idle = SessionConfig.idle // update in case this has changed
            session.data = proxy.data
            session.ipaddress = proxy.ipaddress
            session.useragent = proxy.useragent
            session._state = "resume"
            return session
        } catch {
            print("Error retrieving session: \(error)")
        }
        return nil
	}



	func isError(_ errorMsg: String) -> Bool {
		if errorMsg.contains(string: "ERROR") {
			print(errorMsg)
			return true
		}
		return false
	}
	
}



