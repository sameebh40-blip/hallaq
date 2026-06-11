export function userFacingAuthError(message: string) {
  const m = message.toLowerCase();

  if (m.includes("invalid login credentials")) return "Invalid email or password.";
  if (m.includes("email not confirmed")) return "Please verify your email and try again.";
  if (m.includes("user already registered")) return "An account with this email already exists.";
  if (m.includes("too many") || m.includes("rate limit")) return "Too many attempts. Please try again later.";
  if (m.includes("failed to fetch") || m.includes("network")) {
    return "Could not reach the server. Check your connection and try again.";
  }

  return "Could not complete the request. Please try again.";
}

