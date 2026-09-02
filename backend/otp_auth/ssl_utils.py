import ssl


def ssl_context(verify: bool = True) -> ssl.SSLContext:
    if not verify:
        return ssl._create_unverified_context()
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()
