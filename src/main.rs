use std::net::{SocketAddr, TcpListener};
use std::process;

use axum::routing::get;
use axum::Router;
use socket2::{Domain, Protocol, Socket, Type};
use tokio::net::TcpListener as TokioTcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // You can change this to an IPv6 addr like "[::]:3000" if you like
    let addr: SocketAddr = "0.0.0.0:3000".parse()?;

    let listener = build_listener(addr)?;

    // Basit Axum app
    let app = Router::new()
        .route(
            "/",
            get(|| async {
                let pid = process::id();
                format!("Hello from reuseport! (pid={})", pid)
            })
        )
        .route("/pid", get(|| async { format!("{}", process::id()) }));

    let id = process::id();
    println!("Listening on http://{} (pid={})", addr, id);
    axum::serve(listener, app).await?;
    println!("Server shutdown (pid={})", id);
    Ok(())
}

fn build_listener(addr: SocketAddr) -> anyhow::Result<TokioTcpListener> {
    // Domain is chosen based on the address family
    let domain = match addr {
        SocketAddr::V4(_) => Domain::IPV4,
        SocketAddr::V6(_) => Domain::IPV6
    };

    let socket = Socket::new(domain, Type::STREAM, Some(Protocol::TCP))?;

    // Common good practices
    socket.set_reuse_address(true)?;

    // Enable SO_REUSEPORT where supported (Linux >= 3.9, *BSD/macos have it too)
    // On unsupported targets, this block is simply not compiled.
    #[cfg(any(
        target_os = "linux",
        target_os = "android",
        target_os = "macos",
        target_os = "ios",
        target_os = "freebsd",
        target_os = "openbsd",
        target_os = "netbsd"
    ))]
    {
        socket.set_reuse_port(true)?;
    }

    // Bind & listen
    socket.bind(&addr.into())?;
    socket.listen(1024)?;

    // Tokio requires nonblocking std listener
    socket.set_nonblocking(true)?;

    // Convert to std then tokio listener
    let std_listener: TcpListener = socket.into();
    let listener = TokioTcpListener::from_std(std_listener)?;

    Ok(listener)
}
