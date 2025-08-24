#!/usr/bin/env python3

import os
import json
import urllib.request
import urllib.parse
import readline
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

class DeepSeekTerminal:
    def __init__(self):
        # Configuration
        self.home_dir = Path.home()
        self.config_dir = self.home_dir / ".config" / "deepseek"
        self.config_file = self.config_dir / "config.json"
        self.history_file = self.config_dir / "history.json"
        self.models_file = self.config_dir / "models"
        
        # Default settings
        self.default_model = "deepseek-chat"
        self.default_max_tokens = 2000
        self.default_temperature = 0.7
        self.api_url = "https://api.deepseek.com/v1/chat/completions"
        
        # Current settings
        self.current_model = self.default_model
        self.current_max_tokens = self.default_max_tokens
        self.current_temperature = self.default_temperature
        self.api_key = ""
        
        # Session data
        self.session_messages = []
        
        # Colors for terminal output
        self.colors = {
            'RED': '\033[0;31m',
            'GREEN': '\033[0;32m',
            'YELLOW': '\033[1;33m',
            'BLUE': '\033[0;34m',
            'MAGENTA': '\033[0;35m',
            'CYAN': '\033[0;36m',
            'NC': '\033[0m'  # No Color
        }
        
        # Initialize application
        self.init_app()

    def init_app(self):
        """Initialize the application configuration"""
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Create config file if it doesn't exist
        if not self.config_file.exists():
            default_config = {
                "api_key": "",
                "default_model": self.default_model,
                "default_max_tokens": self.default_max_tokens,
                "default_temperature": self.default_temperature
            }
            self.save_config(default_config)
        
        # Load configuration
        self.load_config()
        
        # Create models file if it doesn't exist
        if not self.models_file.exists():
            with open(self.models_file, 'w') as f:
                f.write("deepseek-chat\ndeepseek-coder\n# Add other models as they become available\n")
        
        # Create history file if it doesn't exist
        if not self.history_file.exists():
            with open(self.history_file, 'w') as f:
                json.dump([], f)

    def load_config(self):
        """Load configuration from file"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                config = json.load(f)
                self.api_key = config.get("api_key", "")
                self.current_model = config.get("default_model", self.default_model)
                self.current_max_tokens = config.get("default_max_tokens", self.default_max_tokens)
                self.current_temperature = config.get("default_temperature", self.default_temperature)

    def save_config(self, config):
        """Save configuration to file"""
        with open(self.config_file, 'w') as f:
            json.dump(config, f, indent=2)

    def print_banner(self):
        """Print the application banner"""
        print(f"{self.colors['GREEN']}")
        print("  ____  _____ ______  _____  ______ _____ _  ________ ")
        print(" |  _ \|  __ \|  _ \|  __ \|  ____|  __ | |/ /  ____|")
        print(" | | | | |__) | |_) | |__) | |__  | |__) | ' /| |__   ")
        print(" | | | |  ___/|  _ <|  _  /|  __| |  _  /|  < |  __|  ")
        print(" | |_| | |    | |_) | | \ \| |____| | \ \| . \| |____ ")
        print(" |____/|_|    |____/|_|  \_\______|_|  \_\_|\_\______|")
        print("")
        print(f"{self.colors['NC']}")
        print(f"{self.colors['YELLOW']}          DeepSeek Terminal Interface{self.colors['NC']}")
        print(f"{self.colors['YELLOW']}         Type '/help' for commands list{self.colors['NC']}")
        print(f"{self.colors['YELLOW']}      Type '/exit' or '/quit' to terminate{self.colors['NC']}")
        print("=" * 50)

    def print_help(self):
        """Print help information"""
        print(f"{self.colors['GREEN']}Available commands:{self.colors['NC']}")
        print(f"  {self.colors['YELLOW']}/help{self.colors['NC']}         - Show this help message")
        print(f"  {self.colors['YELLOW']}/exit{self.colors['NC']}         - Exit the application")
        print(f"  {self.colors['YELLOW']}/quit{self.colors['NC']}         - Exit the application")
        print(f"  {self.colors['YELLOW']}/clear{self.colors['NC']}        - Clear the screen")
        print(f"  {self.colors['YELLOW']}/history{self.colors['NC']}      - Show conversation history")
        print(f"  {self.colors['YELLOW']}/clear-history{self.colors['NC']} - Clear conversation history")
        print(f"  {self.colors['YELLOW']}/model{self.colors['NC']}        - Show or set current model")
        print(f"  {self.colors['YELLOW']}/models{self.colors['NC']}       - List available models")
        print(f"  {self.colors['YELLOW']}/tokens{self.colors['NC']}       - Show or set max tokens")
        print(f"  {self.colors['YELLOW']}/temperature{self.colors['NC']}  - Show or set temperature")
        print(f"  {self.colors['YELLOW']}/config{self.colors['NC']}       - Show current configuration")
        print(f"  {self.colors['YELLOW']}/set-key{self.colors['NC']}      - Set API key")
        print(f"  {self.colors['YELLOW']}/reset{self.colors['NC']}        - Reset current conversation")
        print("")
        print(f"{self.colors['GREEN']}Current settings:{self.colors['NC']}")
        print(f"  Model: {self.colors['MAGENTA']}{self.current_model}{self.colors['NC']}")
        print(f"  Max tokens: {self.colors['MAGENTA']}{self.current_max_tokens}{self.colors['NC']}")
        print(f"  Temperature: {self.colors['MAGENTA']}{self.current_temperature}{self.colors['NC']}")
        print(f"  API key: {self.colors['MAGENTA']}{'Set' if self.api_key else 'Not set'}{self.colors['NC']}")

    def check_api_key(self):
        """Check if API key is set"""
        if not self.api_key:
            print(f"{self.colors['RED']}API key not set!{self.colors['NC']}")
            print(f"Use the command: {self.colors['YELLOW']}/set-key <your_api_key>{self.colors['NC']}")
            return False
        return True

    def make_request(self, prompt):
        """Make API request to DeepSeek using urllib (no external dependencies)"""
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }
        
        data = {
            "model": self.current_model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": self.current_temperature,
            "max_tokens": self.current_max_tokens
        }
        
        try:
            # Encode the data
            json_data = json.dumps(data).encode('utf-8')
            
            # Create the request
            req = urllib.request.Request(self.api_url, data=json_data, headers=headers, method='POST')
            
            # Make the request
            with urllib.request.urlopen(req) as response:
                response_data = response.read().decode('utf-8')
                return json.loads(response_data)
                
        except urllib.error.HTTPError as e:
            print(f"{self.colors['RED']}HTTP Error: {e.code} - {e.reason}{self.colors['NC']}")
            try:
                error_body = e.read().decode('utf-8')
                print(f"{self.colors['RED']}Error details: {error_body}{self.colors['NC']}")
            except:
                pass
            return None
        except urllib.error.URLError as e:
            print(f"{self.colors['RED']}URL Error: {e.reason}{self.colors['NC']}")
            return None
        except Exception as e:
            print(f"{self.colors['RED']}Request failed: {e}{self.colors['NC']}")
            return None

    def process_input(self, user_input):
        """Process user input and get response from DeepSeek"""
        if not self.check_api_key():
            return
        
        # Add user message to session
        self.session_messages.append({
            "role": "user",
            "content": user_input,
            "timestamp": datetime.now().isoformat()
        })
        
        print(f"{self.colors['BLUE']}Thinking...{self.colors['NC']}")
        
        response = self.make_request(user_input)
        if not response:
            return
        
        # Extract assistant's reply
        try:
            assistant_reply = response["choices"][0]["message"]["content"]
        except (KeyError, IndexError):
            print(f"{self.colors['RED']}Error: Could not parse response{self.colors['NC']}")
            return
        
        # Add assistant message to session
        self.session_messages.append({
            "role": "assistant",
            "content": assistant_reply,
            "timestamp": datetime.now().isoformat()
        })
        
        # Save to history
        self.save_to_history()
        
        # Display the response with formatting
        print(f"{self.colors['GREEN']}DeepSeek:{self.colors['NC']}")
        print(self.wrap_text(assistant_reply, 80))
        print("")

    def wrap_text(self, text, width):
        """Wrap text to specified width"""
        words = text.split()
        lines = []
        current_line = []
        current_length = 0
        
        for word in words:
            if current_length + len(word) + 1 > width:
                lines.append(" ".join(current_line))
                current_line = [word]
                current_length = len(word)
            else:
                current_line.append(word)
                current_length += len(word) + 1
        
        if current_line:
            lines.append(" ".join(current_line))
        
        return "\n".join(lines)

    def save_to_history(self):
        """Save current session to history file"""
        try:
            if self.history_file.exists():
                with open(self.history_file, 'r') as f:
                    history = json.load(f)
            else:
                history = []
            
            history.extend(self.session_messages)
            
            with open(self.history_file, 'w') as f:
                json.dump(history, f, indent=2)
        except Exception as e:
            print(f"{self.colors['RED']}Error saving history: {e}{self.colors['NC']}")

    def show_history(self):
        """Show conversation history"""
        if not self.history_file.exists():
            print("No history found.")
            return
        
        try:
            with open(self.history_file, 'r') as f:
                history = json.load(f)
            
            if not history:
                print("No history found.")
                return
            
            print(f"{self.colors['YELLOW']}Conversation history:{self.colors['NC']}")
            for i, message in enumerate(history[-10:]):  # Show last 10 messages
                timestamp = datetime.fromisoformat(message["timestamp"]).strftime("%Y-%m-%d %H:%M:%S")
                if message["role"] == "user":
                    print(f"{self.colors['CYAN']}[{timestamp}] You:{self.colors['NC']} {message['content']}")
                else:
                    print(f"{self.colors['GREEN']}[{timestamp}] DeepSeek:{self.colors['NC']} {message['content']}")
                print()
        except Exception as e:
            print(f"{self.colors['RED']}Error reading history: {e}{self.colors['NC']}")

    def clear_history(self):
        """Clear conversation history"""
        try:
            with open(self.history_file, 'w') as f:
                json.dump([], f)
            print(f"{self.colors['GREEN']}History cleared.{self.colors['NC']}")
        except Exception as e:
            print(f"{self.colors['RED']}Error clearing history: {e}{self.colors['NC']}")

    def list_models(self):
        """List available models"""
        if not self.models_file.exists():
            print(f"{self.colors['YELLOW']}No models file found.{self.colors['NC']}")
            return
        
        try:
            with open(self.models_file, 'r') as f:
                models = [line.strip() for line in f if line.strip() and not line.startswith('#')]
            
            print(f"{self.colors['YELLOW']}Available models:{self.colors['NC']}")
            for i, model in enumerate(models, 1):
                print(f"  {i}. {model}")
        except Exception as e:
            print(f"{self.colors['RED']}Error reading models: {e}{self.colors['NC']}")

    def set_api_key(self, key):
        """Set API key"""
        if not key:
            print(f"{self.colors['RED']}API key cannot be empty.{self.colors['NC']}")
            return
        
        self.api_key = key
        
        # Update config file
        config = {
            "api_key": self.api_key,
            "default_model": self.current_model,
            "default_max_tokens": self.current_max_tokens,
            "default_temperature": self.current_temperature
        }
        
        self.save_config(config)
        print(f"{self.colors['GREEN']}API key set successfully.{self.colors['NC']}")

    def show_config(self):
        """Show current configuration"""
        print(f"{self.colors['YELLOW']}Current configuration:{self.colors['NC']}")
        print(f"  Model: {self.colors['MAGENTA']}{self.current_model}{self.colors['NC']}")
        print(f"  Max tokens: {self.colors['MAGENTA']}{self.current_max_tokens}{self.colors['NC']}")
        print(f"  Temperature: {self.colors['MAGENTA']}{self.current_temperature}{self.colors['NC']}")
        print(f"  API key: {self.colors['MAGENTA']}{'Set' if self.api_key else 'Not set'}{self.colors['NC']}")

    def reset_conversation(self):
        """Reset current conversation"""
        self.session_messages = []
        print(f"{self.colors['GREEN']}Conversation reset.{self.colors['NC']}")

    def run(self):
        """Main application loop"""
        self.print_banner()
        
        while True:
            try:
                user_input = input(f"{self.colors['YELLOW']}deepseek> {self.colors['NC']}").strip()
                
                if not user_input:
                    continue
                
                # Handle commands
                if user_input.startswith('/'):
                    command = user_input[1:].split()[0].lower()
                    args = user_input[1:].split()[1:]
                    
                    if command in ['exit', 'quit']:
                        print(f"{self.colors['GREEN']}Goodbye!{self.colors['NC']}")
                        break
                    elif command == 'help':
                        self.print_help()
                    elif command == 'clear':
                        os.system('clear' if os.name == 'posix' else 'cls')
                        self.print_banner()
                    elif command == 'history':
                        self.show_history()
                    elif command == 'clear-history':
                        self.clear_history()
                    elif command == 'model':
                        if args:
                            new_model = ' '.join(args)
                            # Check if model is available
                            if self.models_file.exists():
                                with open(self.models_file, 'r') as f:
                                    models = [line.strip() for line in f if line.strip() and not line.startswith('#')]
                                if new_model in models:
                                    self.current_model = new_model
                                    print(f"{self.colors['GREEN']}Model switched to: {self.current_model}{self.colors['NC']}")
                                    
                                    # Update config
                                    config = {
                                        "api_key": self.api_key,
                                        "default_model": self.current_model,
                                        "default_max_tokens": self.current_max_tokens,
                                        "default_temperature": self.current_temperature
                                    }
                                    self.save_config(config)
                                else:
                                    print(f"{self.colors['RED']}Unknown model. Use '/models' to see available options.{self.colors['NC']}")
                            else:
                                print(f"{self.colors['RED']}Cannot verify model availability.{self.colors['NC']}")
                        else:
                            print(f"Current model: {self.colors['MAGENTA']}{self.current_model}{self.colors['NC']}")
                    elif command == 'models':
                        self.list_models()
                    elif command == 'tokens':
                        if args:
                            try:
                                new_tokens = int(args[0])
                                if new_tokens > 0:
                                    self.current_max_tokens = new_tokens
                                    print(f"{self.colors['GREEN']}Max tokens set to: {self.current_max_tokens}{self.colors['NC']}")
                                    
                                    # Update config
                                    config = {
                                        "api_key": self.api_key,
                                        "default_model": self.current_model,
                                        "default_max_tokens": self.current_max_tokens,
                                        "default_temperature": self.current_temperature
                                    }
                                    self.save_config(config)
                                else:
                                    print(f"{self.colors['RED']}Max tokens must be a positive integer.{self.colors['NC']}")
                            except ValueError:
                                print(f"{self.colors['RED']}Please enter a valid number.{self.colors['NC']}")
                        else:
                            print(f"Max tokens: {self.colors['MAGENTA']}{self.current_max_tokens}{self.colors['NC']}")
                    elif command == 'temperature':
                        if args:
                            try:
                                new_temp = float(args[0])
                                if 0 <= new_temp <= 1:
                                    self.current_temperature = new_temp
                                    print(f"{self.colors['GREEN']}Temperature set to: {self.current_temperature}{self.colors['NC']}")
                                    
                                    # Update config
                                    config = {
                                        "api_key": self.api_key,
                                        "default_model": self.current_model,
                                        "default_max_tokens": self.current_max_tokens,
                                        "default_temperature": self.current_temperature
                                    }
                                    self.save_config(config)
                                else:
                                    print(f"{self.colors['RED']}Temperature must be between 0 and 1.{self.colors['NC']}")
                            except ValueError:
                                print(f"{self.colors['RED']}Please enter a valid number.{self.colors['NC']}")
                        else:
                            print(f"Temperature: {self.colors['MAGENTA']}{self.current_temperature}{self.colors['NC']}")
                    elif command == 'config':
                        self.show_config()
                    elif command == 'set-key':
                        if args:
                            self.set_api_key(' '.join(args))
                        else:
                            print(f"{self.colors['RED']}Please provide an API key.{self.colors['NC']}")
                    elif command == 'reset':
                        self.reset_conversation()
                    else:
                        print(f"{self.colors['RED']}Unknown command. Type '/help' for available commands.{self.colors['NC']}")
                else:
                    # Process regular input
                    self.process_input(user_input)
            
            except KeyboardInterrupt:
                print(f"\n{self.colors['GREEN']}Goodbye!{self.colors['NC']}")
                break
            except Exception as e:
                print(f"{self.colors['RED']}An error occurred: {e}{self.colors['NC']}")

def main():
    app = DeepSeekTerminal()
    app.run()

if __name__ == "__main__":
    main()
