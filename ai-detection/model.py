import torch
import torch.nn as nn
import torch.nn.functional as F


class CNN1D(nn.Module):
    """1D Convolutional Neural Network for tabular data"""

    def __init__(self, in_channels=1, num_classes=4, dropout=0.3):
        super().__init__()
        self.net = nn.Sequential(
            # Block 1
            nn.Conv1d(in_channels, 64, kernel_size=5, stride=1, padding=2),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            nn.Dropout(dropout),

            # Block 2
            nn.Conv1d(64, 128, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.Dropout(dropout),

            # Block 3
            nn.Conv1d(128, 128, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(128),
            nn.ReLU(),

            # Global average pooling
            nn.AdaptiveAvgPool1d(1)
        )
        self.head = nn.Linear(128, num_classes)

    def forward(self, x):
        z = self.net(x)               # (B, 128, 1)
        z = z.squeeze(-1)             # (B, 128)
        return self.head(z)           # logits


class MLP(nn.Module):
    """Multi-Layer Perceptron - matches training architecture"""

    def __init__(self, input_dim=76, hidden_dims=[128, 64, 32], output_dim=4, dropout=0.3):
        super().__init__()
        self.model = nn.Sequential(
            nn.Linear(input_dim, hidden_dims[0]),
            nn.ReLU(),
            nn.Dropout(dropout),

            nn.Linear(hidden_dims[0], hidden_dims[1]),
            nn.ReLU(),
            nn.Dropout(dropout),

            nn.Linear(hidden_dims[1], hidden_dims[2]),
            nn.ReLU(),
            nn.Dropout(dropout),

            nn.Linear(hidden_dims[2], output_dim)
        )

    def forward(self, x):
        return self.model(x)


class RNN(nn.Module):
    """Recurrent Neural Network - matches training architecture"""

    def __init__(self, input_size=1, hidden_size=128, num_layers=2,
                 nonlinearity='tanh', bidirectional=False, dropout=0.3, num_classes=4):
        super().__init__()
        self.bidirectional = bidirectional
        self.rnn = nn.RNN(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            nonlinearity=nonlinearity,  # 'tanh' or 'relu'
            batch_first=True,
            dropout=(dropout if num_layers > 1 else 0.0),
            bidirectional=bidirectional
        )
        out_dim = hidden_size * (2 if bidirectional else 1)
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(out_dim, num_classes)

    def forward(self, x):
        # x: (B, 76, 1)
        # rnn_out: (B, 76, H*[2 if bi]) ; h_n: (L*[2 if bi], B, H)
        rnn_out, h_n = self.rnn(x)
        # Take the last layer's hidden state (concatenate directions if bidirectional)
        if self.bidirectional:
            # h_n shape: (num_layers*2, B, H) -> take last layer's two directions and concat
            h_last_f = h_n[-2]  # forward
            h_last_b = h_n[-1]  # backward
            h = torch.cat([h_last_f, h_last_b], dim=1)  # (B, 2H)
        else:
            h = h_n[-1]  # (B, H)
        h = self.dropout(h)
        logits = self.fc(h)  # (B, C)
        return logits


class LSTM(nn.Module):
    """Long Short-Term Memory Network - matches training architecture"""

    def __init__(self, input_size=1, hidden_size=128, num_layers=2,
                 bidirectional=False, dropout=0.3, num_classes=4):
        super().__init__()
        self.bidirectional = bidirectional
        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=(dropout if num_layers > 1 else 0.0),
            bidirectional=bidirectional
        )
        out_dim = hidden_size * (2 if bidirectional else 1)
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(out_dim, num_classes)

    def forward(self, x):
        # x: (B, 76, 1)
        # lstm_out: (B, 76, H[*2]); (h_n, c_n): (L[*2], B, H)
        lstm_out, (h_n, c_n) = self.lstm(x)
        if self.bidirectional:
            # h_n shape: (num_layers*2, B, H) -> take last layer's two directions and concat
            h_last_f = h_n[-2]  # forward of last layer
            h_last_b = h_n[-1]  # backward of last layer
            h = torch.cat([h_last_f, h_last_b], dim=1)  # (B, 2H)
        else:
            h = h_n[-1]  # (B, H)
        h = self.dropout(h)
        logits = self.fc(h)  # (B, C)
        return logits


class GRU(nn.Module):
    """Gated Recurrent Unit Network - matches training architecture"""

    def __init__(self, input_size=1, hidden_size=128, num_layers=2,
                 bidirectional=False, dropout=0.3, num_classes=4):
        super().__init__()
        self.bidirectional = bidirectional
        self.gru = nn.GRU(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=(dropout if num_layers > 1 else 0.0),
            bidirectional=bidirectional
        )
        out_dim = hidden_size * (2 if bidirectional else 1)
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(out_dim, num_classes)

    def forward(self, x):
        # x: (B, 76, 1)
        # gru_out: (B, 76, H*[2 if bi]) ; h_n: (L*[2 if bi], B, H)
        gru_out, h_n = self.gru(x)
        if self.bidirectional:
            # h_n shape: (num_layers*2, B, H) -> take last layer's two directions and concat
            h_last_f = h_n[-2]  # forward
            h_last_b = h_n[-1]  # backward
            h = torch.cat([h_last_f, h_last_b], dim=1)  # (B, 2H)
        else:
            h = h_n[-1]  # (B, H)
        h = self.dropout(h)
        logits = self.fc(h)  # (B, C)
        return logits


class Autoencoder(nn.Module):
    """Supervised Autoencoder for classification - matches training architecture"""

    def __init__(self, input_dim=76, enc_dims=(128, 64), latent_dim=16,
                 dec_dims=(64, 128), num_classes=4, dropout=0.2):
        super().__init__()
        # Encoder
        layers = []
        prev = input_dim
        for h in enc_dims:
            layers += [nn.Linear(prev, h), nn.ReLU(), nn.Dropout(dropout)]
            prev = h
        layers += [nn.Linear(prev, latent_dim)]  # latent
        self.encoder = nn.Sequential(*layers)

        # Classifier head (on latent)
        self.classifier = nn.Sequential(
            nn.ReLU(),                      # a little nonlinearity post-latent
            nn.Dropout(dropout),
            nn.Linear(latent_dim, num_classes)
        )

        # Decoder (mirror-ish)
        layers = []
        prev = latent_dim
        for h in dec_dims:
            layers += [nn.Linear(prev, h), nn.ReLU(), nn.Dropout(dropout)]
            prev = h
        layers += [nn.Linear(prev, input_dim)]
        self.decoder = nn.Sequential(*layers)

    def forward(self, x):
        z = self.encoder(x)            # (B, latent_dim)
        logits = self.classifier(z)    # (B, C)
        x_hat = self.decoder(z)        # (B, input_dim)
        return logits, x_hat, z

    def encode(self, x):
        return self.encoder(x)


# Model factory function
def create_model(model_type, num_classes=4, **kwargs):
    """Factory function to create model instances with training-matched architectures"""
    models = {
        'cnn': CNN1D,
        'mlp': MLP,
        'rnn': RNN,
        'lstm': LSTM,
        'gru': GRU,
        'autoencoder': Autoencoder
    }

    if model_type not in models:
        raise ValueError(f"Unknown model type: {model_type}. Available: {list(models.keys())}")

    # Set default parameters that match training
    defaults = {
        'cnn': {'in_channels': 1, 'num_classes': num_classes, 'dropout': 0.3},
        'mlp': {'input_dim': 76, 'hidden_dims': [128, 64, 32], 'output_dim': num_classes, 'dropout': 0.3},
        'rnn': {'input_size': 1, 'hidden_size': 128, 'num_layers': 2, 'nonlinearity': 'tanh',
                'bidirectional': False, 'dropout': 0.3, 'num_classes': num_classes},
        'lstm': {'input_size': 1, 'hidden_size': 128, 'num_layers': 2, 'bidirectional': False,
                 'dropout': 0.3, 'num_classes': num_classes},
        'gru': {'input_size': 1, 'hidden_size': 128, 'num_layers': 2, 'bidirectional': False,
                'dropout': 0.3, 'num_classes': num_classes},
        'autoencoder': {'input_dim': 76, 'enc_dims': (128, 64), 'latent_dim': 16,
                       'dec_dims': (64, 128), 'num_classes': num_classes, 'dropout': 0.2}
    }

    # Merge defaults with provided kwargs
    params = {**defaults.get(model_type, {}), **kwargs}

    return models[model_type](**params)


# Class names mapping
CLASS_NAMES = ['ddos', 'normal', 'probe', 'tls']
